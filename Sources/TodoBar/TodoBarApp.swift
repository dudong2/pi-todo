import AppKit
import SwiftUI

@main
struct TodoBarApp: App {
  @StateObject private var model = TodoListModel()

  init() {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  var body: some Scene {
    MenuBarExtra {
      TodoBarView(model: model)
    } label: {
      Label("Todo Bar, \(model.incompleteCount) incomplete", systemImage: "checklist")
    }
    .menuBarExtraStyle(.window)
  }
}
