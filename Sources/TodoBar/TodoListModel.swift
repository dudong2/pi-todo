import Foundation
import TodoCore

struct TodoProjectGroup: Identifiable {
  let project: String
  let todos: [Todo]

  var id: String { project }
}

@MainActor
final class TodoListModel: ObservableObject {
  @Published private(set) var todos: [Todo] = []
  @Published private(set) var errorMessage: String?
  @Published private(set) var loginItemMessage: String?

  private let store: TodoStore?
  private var notificationToken: NSObjectProtocol?

  init() {
    loginItemMessage = LoginItemManager.registerIfNeeded()

    do {
      store = try TodoStore()
      errorMessage = nil
    } catch {
      store = nil
      errorMessage = error.localizedDescription
    }

    notificationToken = DistributedNotificationCenter.default().addObserver(
      forName: TodoNotifications.didChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.reload()
      }
    }
    reload()
  }

  deinit {
    if let notificationToken {
      DistributedNotificationCenter.default().removeObserver(notificationToken)
    }
  }

  var incompleteCount: Int { todos.count }

  var groups: [TodoProjectGroup] {
    Dictionary(grouping: todos, by: \.project)
      .map { TodoProjectGroup(project: $0.key, todos: $0.value) }
      .sorted { left, right in
        let leftDate = left.todos.map(\.createdAt).max() ?? .distantPast
        let rightDate = right.todos.map(\.createdAt).max() ?? .distantPast
        if leftDate != rightDate { return leftDate > rightDate }
        return left.project.localizedCaseInsensitiveCompare(right.project) == .orderedAscending
      }
  }

  func reload() {
    guard let store else { return }
    do {
      todos = try store.list()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func complete(_ todo: Todo) {
    guard let store else { return }
    do {
      try store.complete(id: todo.id)
      reload()
      TodoNotifications.postChange()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
