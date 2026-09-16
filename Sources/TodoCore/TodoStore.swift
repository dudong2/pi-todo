import Foundation
import SQLite3

public enum TodoStoreError: LocalizedError {
  case invalidProject
  case invalidTitle
  case notFound(String)
  case sqlite(code: Int32, message: String)

  public var errorDescription: String? {
    switch self {
    case .invalidProject:
      return "Project must not be empty."
    case .invalidTitle:
      return "Title must not be empty."
    case .notFound(let id):
      return "Todo not found: \(id)"
    case .sqlite(let code, let message):
      return "SQLite error \(code): \(message)"
    }
  }
}

public final class TodoStore {
  private var database: OpaquePointer?
  private let lock = NSLock()

  public init(databaseURL: URL = AppPaths.databaseURL) throws {
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    var connection: OpaquePointer?
    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    let result = sqlite3_open_v2(databaseURL.path, &connection, flags, nil)
    guard result == SQLITE_OK, let connection else {
      let message =
        connection.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database."
      if let connection {
        sqlite3_close(connection)
      }
      throw TodoStoreError.sqlite(code: result, message: message)
    }

    database = connection
    sqlite3_busy_timeout(connection, 5_000)

    do {
      try execute("PRAGMA journal_mode = WAL;")
      try execute("PRAGMA foreign_keys = ON;")
      try execute("BEGIN IMMEDIATE;")
      do {
        try execute(
          """
          CREATE TABLE IF NOT EXISTS todos (
              id TEXT PRIMARY KEY,
              project TEXT NOT NULL CHECK(length(trim(project)) > 0),
              title TEXT NOT NULL CHECK(length(trim(title)) > 0),
              details TEXT NOT NULL DEFAULT '',
              created_at REAL NOT NULL,
              completed_at REAL
          );
          """
        )
        if try !hasColumn(named: "details", in: "todos") {
          try execute("ALTER TABLE todos ADD COLUMN details TEXT NOT NULL DEFAULT '';")
        }
        try execute(
          """
          CREATE INDEX IF NOT EXISTS todos_incomplete_project_created
          ON todos(project, created_at)
          WHERE completed_at IS NULL;
          """
        )
        try execute("COMMIT;")
      } catch {
        try? execute("ROLLBACK;")
        throw error
      }
    } catch {
      sqlite3_close(connection)
      database = nil
      throw error
    }
  }

  deinit {
    if let database {
      sqlite3_close(database)
    }
  }

  @discardableResult
  public func add(
    project: String,
    title: String,
    details: String = "",
    now: Date = Date()
  ) throws -> Todo {
    let project = project.trimmingCharacters(in: .whitespacesAndNewlines)
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let details = details.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !project.isEmpty else { throw TodoStoreError.invalidProject }
    guard !title.isEmpty else { throw TodoStoreError.invalidTitle }

    let todo = Todo(
      id: UUID().uuidString.lowercased(),
      project: project,
      title: title,
      details: details,
      createdAt: now,
      completedAt: nil
    )

    try withStatement(
      "INSERT INTO todos (id, project, title, details, created_at) VALUES (?, ?, ?, ?, ?);"
    ) { statement in
      try bind(todo.id, to: 1, in: statement)
      try bind(todo.project, to: 2, in: statement)
      try bind(todo.title, to: 3, in: statement)
      try bind(todo.details, to: 4, in: statement)
      try check(sqlite3_bind_double(statement, 5, now.timeIntervalSince1970))
      try stepDone(statement)
    }
    return todo
  }

  public func list(includeCompleted: Bool = false) throws -> [Todo] {
    let filter = includeCompleted ? "" : "WHERE completed_at IS NULL"
    return try withStatement(
      """
      SELECT id, project, title, details, created_at, completed_at
      FROM todos
      \(filter)
      ORDER BY created_at DESC, id ASC;
      """
    ) { statement in
      var todos: [Todo] = []
      while true {
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE {
          return todos
        }
        guard result == SQLITE_ROW else {
          throw sqliteError(code: result)
        }

        let completedAt: Date?
        if sqlite3_column_type(statement, 5) == SQLITE_NULL {
          completedAt = nil
        } else {
          completedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
        }

        todos.append(
          Todo(
            id: text(at: 0, in: statement),
            project: text(at: 1, in: statement),
            title: text(at: 2, in: statement),
            details: text(at: 3, in: statement),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
            completedAt: completedAt
          )
        )
      }
    }
  }

  public func complete(id: String, now: Date = Date()) throws {
    try withStatement(
      "UPDATE todos SET completed_at = ? WHERE id = ? AND completed_at IS NULL;"
    ) { statement in
      try check(sqlite3_bind_double(statement, 1, now.timeIntervalSince1970))
      try bind(id, to: 2, in: statement)
      try stepDone(statement)
      guard sqlite3_changes(database) == 1 else {
        throw TodoStoreError.notFound(id)
      }
    }
  }

  private func hasColumn(named columnName: String, in tableName: String) throws -> Bool {
    try withStatement("PRAGMA table_info(\(tableName));") { statement in
      while true {
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE {
          return false
        }
        guard result == SQLITE_ROW else {
          throw sqliteError(code: result)
        }
        if text(at: 1, in: statement) == columnName {
          return true
        }
      }
    }
  }

  private func execute(_ sql: String) throws {
    lock.lock()
    defer { lock.unlock() }

    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
    guard result == SQLITE_OK else {
      let message =
        errorMessage.map { String(cString: $0) } ?? sqliteError(code: result).localizedDescription
      sqlite3_free(errorMessage)
      throw TodoStoreError.sqlite(code: result, message: message)
    }
  }

  private func withStatement<T>(_ sql: String, body: (OpaquePointer) throws -> T) throws -> T {
    lock.lock()
    defer { lock.unlock() }

    var statement: OpaquePointer?
    let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
    guard result == SQLITE_OK, let statement else {
      throw sqliteError(code: result)
    }
    defer { sqlite3_finalize(statement) }
    return try body(statement)
  }

  private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) throws {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    try check(sqlite3_bind_text(statement, index, value, -1, transient))
  }

  private func stepDone(_ statement: OpaquePointer) throws {
    let result = sqlite3_step(statement)
    guard result == SQLITE_DONE else {
      throw sqliteError(code: result)
    }
  }

  private func check(_ result: Int32) throws {
    guard result == SQLITE_OK else {
      throw sqliteError(code: result)
    }
  }

  private func text(at index: Int32, in statement: OpaquePointer) -> String {
    guard let value = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: value)
  }

  private func sqliteError(code: Int32) -> TodoStoreError {
    let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown database error."
    return .sqlite(code: code, message: message)
  }
}
