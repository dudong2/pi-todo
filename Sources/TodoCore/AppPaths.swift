import Foundation

public enum AppPaths {
  public static var applicationSupportDirectory: URL {
    FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Todo Bar", isDirectory: true)
  }

  public static var databaseURL: URL {
    if let override = ProcessInfo.processInfo.environment["TODO_BAR_DATABASE"],
      !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
    }
    return applicationSupportDirectory.appendingPathComponent("todos.sqlite")
  }
}

public enum TodoNotifications {
  public static let didChange = Notification.Name("com.dudong2.TodoBar.todosDidChange")

  public static func postChange() {
    DistributedNotificationCenter.default().postNotificationName(
      didChange,
      object: nil,
      userInfo: nil,
      deliverImmediately: true
    )
  }
}
