import Foundation
import SQLite3
import XCTest

@testable import TodoCore

final class TodoStoreTests: XCTestCase {
  private var temporaryDirectory: URL!
  private var databaseURL: URL!

  override func setUpWithError() throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    databaseURL = temporaryDirectory.appendingPathComponent("todos.sqlite")
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: temporaryDirectory)
  }

  func testAddPersistsAcrossStoreInstancesAndCompleteHidesTodo() throws {
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    var firstStore: TodoStore? = try TodoStore(databaseURL: databaseURL)
    let added = try firstStore?.add(
      project: "pi-todo",
      title: "Build menu bar app",
      details: "Background: The current popover loses task context.",
      now: createdAt
    )
    XCTAssertEqual(try firstStore?.list().count, 1)
    firstStore = nil

    let reopenedStore = try TodoStore(databaseURL: databaseURL)
    let persisted = try XCTUnwrap(reopenedStore.list().first)
    XCTAssertEqual(persisted.id, added?.id)
    XCTAssertEqual(persisted.project, "pi-todo")
    XCTAssertEqual(persisted.title, "Build menu bar app")
    XCTAssertEqual(persisted.details, "Background: The current popover loses task context.")
    XCTAssertEqual(persisted.createdAt, createdAt)
    XCTAssertNil(persisted.completedAt)

    try reopenedStore.complete(id: persisted.id, now: createdAt.addingTimeInterval(60))
    XCTAssertTrue(try reopenedStore.list().isEmpty)

    let completed = try XCTUnwrap(reopenedStore.list(includeCompleted: true).first)
    XCTAssertEqual(completed.completedAt, createdAt.addingTimeInterval(60))
  }

  func testMigratesExistingDatabaseWithoutLosingTodos() throws {
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(databaseURL.path, &database), SQLITE_OK)
    defer {
      if let database {
        sqlite3_close(database)
      }
    }
    XCTAssertEqual(
      sqlite3_exec(
        database,
        """
        CREATE TABLE todos (
          id TEXT PRIMARY KEY,
          project TEXT NOT NULL,
          title TEXT NOT NULL,
          created_at REAL NOT NULL,
          completed_at REAL
        );
        INSERT INTO todos VALUES ('legacy', 'pi-todo', 'Legacy todo', 1700000000, NULL);
        """,
        nil,
        nil,
        nil
      ),
      SQLITE_OK
    )
    sqlite3_close(database)
    database = nil

    let store = try TodoStore(databaseURL: databaseURL)
    let todo = try XCTUnwrap(store.list().first)
    XCTAssertEqual(todo.id, "legacy")
    XCTAssertEqual(todo.title, "Legacy todo")
    XCTAssertEqual(todo.details, "")
  }

  func testRejectsBlankProjectAndTitle() throws {
    let store = try TodoStore(databaseURL: databaseURL)
    XCTAssertThrowsError(try store.add(project: "  ", title: "Task"))
    XCTAssertThrowsError(try store.add(project: "Project", title: "\n"))
  }

  func testCompleteRejectsMissingOrAlreadyCompletedTodo() throws {
    let store = try TodoStore(databaseURL: databaseURL)
    XCTAssertThrowsError(try store.complete(id: "missing"))

    let todo = try store.add(project: "Project", title: "Task")
    try store.complete(id: todo.id)
    XCTAssertThrowsError(try store.complete(id: todo.id))
  }
}
