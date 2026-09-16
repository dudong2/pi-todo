import Darwin
import Foundation
import TodoCore

@main
struct TodoCLI {
  static func main() {
    do {
      try run()
    } catch {
      writeError("todoctl: \(error.localizedDescription)\n")
      exit(EXIT_FAILURE)
    }
  }

  private static func run() throws {
    var arguments = Array(CommandLine.arguments.dropFirst())
    let databaseURL = try extractDatabaseURL(from: &arguments) ?? AppPaths.databaseURL

    guard let command = arguments.first else {
      printUsage()
      return
    }
    arguments.removeFirst()

    let store = try TodoStore(databaseURL: databaseURL)
    switch command {
    case "add":
      let options = try parseOptions(arguments, allowed: ["--project", "--title", "--details"])
      guard let project = options["--project"] else {
        throw CLIError.usage("add requires --project.")
      }
      guard let title = options["--title"] else {
        throw CLIError.usage("add requires --title.")
      }
      let todo = try store.add(
        project: project,
        title: title,
        details: options["--details"] ?? ""
      )
      TodoNotifications.postChange()
      print("Added \(todo.id): [\(todo.project)] \(todo.title)")

    case "list":
      let includeCompleted = arguments.contains("--all")
      let json = arguments.contains("--json")
      let unknown = arguments.filter { $0 != "--all" && $0 != "--json" }
      guard unknown.isEmpty else {
        throw CLIError.usage("Unknown list option: \(unknown[0])")
      }
      let todos = try store.list(includeCompleted: includeCompleted)
      if json {
        print(try encode(todos))
      } else {
        for todo in todos {
          let marker = todo.completedAt == nil ? "[ ]" : "[x]"
          print("\(marker)\t\(todo.id)\t\(todo.project)\t\(todo.title)")
          if !todo.details.isEmpty {
            print("\t\(todo.details.replacingOccurrences(of: "\n", with: "\n\t"))")
          }
        }
      }

    case "complete":
      guard arguments.count == 1, let id = arguments.first else {
        throw CLIError.usage("complete requires exactly one todo ID.")
      }
      try store.complete(id: id)
      TodoNotifications.postChange()
      print("Completed \(id)")

    case "help", "--help", "-h":
      printUsage()

    default:
      throw CLIError.usage("Unknown command: \(command)")
    }
  }

  private static func extractDatabaseURL(from arguments: inout [String]) throws -> URL? {
    guard let index = arguments.firstIndex(of: "--database") else { return nil }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else {
      throw CLIError.usage("--database requires a path.")
    }
    let path = NSString(string: arguments[valueIndex]).expandingTildeInPath
    arguments.removeSubrange(index...valueIndex)
    return URL(fileURLWithPath: path)
  }

  private static func parseOptions(_ arguments: [String], allowed: Set<String>) throws -> [String:
    String]
  {
    var result: [String: String] = [:]
    var index = arguments.startIndex
    while index < arguments.endIndex {
      let option = arguments[index]
      guard allowed.contains(option) else {
        throw CLIError.usage("Unknown option: \(option)")
      }
      let valueIndex = arguments.index(after: index)
      guard valueIndex < arguments.endIndex else {
        throw CLIError.usage("\(option) requires a value.")
      }
      result[option] = arguments[valueIndex]
      index = arguments.index(after: valueIndex)
    }
    return result
  }

  private static func encode(_ todos: [Todo]) throws -> String {
    let output = todos.map(OutputTodo.init)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(decoding: try encoder.encode(output), as: UTF8.self)
  }

  private static func printUsage() {
    print(
      """
      Usage:
        todoctl add --project <project> --title <title> [--details <details>]
        todoctl list [--all] [--json]
        todoctl complete <id>

      Options:
        --database <path>  Override the default database location.
      """
    )
  }

  private static func writeError(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
  }
}

private struct OutputTodo: Encodable {
  let id: String
  let project: String
  let title: String
  let details: String
  let createdAt: Date
  let completedAt: Date?

  init(_ todo: Todo) {
    id = todo.id
    project = todo.project
    title = todo.title
    details = todo.details
    createdAt = todo.createdAt
    completedAt = todo.completedAt
  }

  enum CodingKeys: String, CodingKey {
    case id, project, title, details
    case createdAt = "created_at"
    case completedAt = "completed_at"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(project, forKey: .project)
    try container.encode(title, forKey: .title)
    try container.encode(details, forKey: .details)
    try container.encode(createdAt, forKey: .createdAt)
    if let completedAt {
      try container.encode(completedAt, forKey: .completedAt)
    } else {
      try container.encodeNil(forKey: .completedAt)
    }
  }
}

private enum CLIError: LocalizedError {
  case usage(String)

  var errorDescription: String? {
    switch self {
    case .usage(let message): return message
    }
  }
}
