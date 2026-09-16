import AppKit
import SwiftUI
import TodoCore

struct TodoBarView: View {
  @ObservedObject var model: TodoListModel
  @State private var expandedTodoIDs: Set<String> = []
  private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  private var listHeight: CGFloat {
    min(620, max(360, CGFloat(model.todos.count * 96 + model.groups.count * 40 + 40)))
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()

      if let errorMessage = model.errorMessage {
        errorView(errorMessage)
      } else if model.todos.isEmpty {
        emptyView
      } else {
        todoList
      }

      Divider()
      footer
    }
    .frame(width: 520)
    .onAppear { model.reload() }
    .onReceive(refreshTimer) { _ in model.reload() }
  }

  private var header: some View {
    HStack {
      Text("Todo Bar")
        .font(.headline)
      Spacer()
      Text("\(model.incompleteCount)")
        .font(.body.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())
        .accessibilityLabel("\(model.incompleteCount) incomplete todos")
    }
    .padding(16)
  }

  private var todoList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 20) {
        ForEach(model.groups) { group in
          VStack(alignment: .leading, spacing: 5) {
            HStack {
              Text(group.project)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Spacer()
              Text("\(group.todos.count)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.tertiary)
            }

            ForEach(group.todos) { todo in
              todoRow(todo)
            }
          }
        }
      }
      .padding(16)
    }
    .frame(height: listHeight)
  }

  private func todoRow(_ todo: Todo) -> some View {
    let isExpanded = expandedTodoIDs.contains(todo.id)

    return HStack(alignment: .top, spacing: 12) {
      Button {
        model.complete(todo)
        expandedTodoIDs.remove(todo.id)
      } label: {
        Image(systemName: "circle")
          .font(.title3)
          .foregroundStyle(.secondary)
          .frame(width: 22, height: 22)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Complete \(todo.title)")

      Button {
        guard !todo.details.isEmpty else { return }
        if isExpanded {
          expandedTodoIDs.remove(todo.id)
        } else {
          expandedTodoIDs.insert(todo.id)
        }
      } label: {
        HStack(alignment: .top, spacing: 8) {
          VStack(alignment: .leading, spacing: 7) {
            Text(todo.title)
              .font(.title3.weight(.semibold))
              .foregroundStyle(.primary)
              .multilineTextAlignment(.leading)

            if !todo.details.isEmpty {
              Text(todo.details)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if !todo.details.isEmpty {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.body.weight(.semibold))
              .foregroundStyle(.tertiary)
              .padding(.top, 3)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(todo.details.isEmpty)
      .accessibilityLabel(
        todo.details.isEmpty
          ? todo.title
          : "\(isExpanded ? "Collapse" : "Expand") details for \(todo.title)"
      )
    }
    .padding(.vertical, 7)
  }

  private var emptyView: some View {
    VStack(spacing: 6) {
      Image(systemName: "checkmark.circle")
        .font(.title2)
        .foregroundStyle(.secondary)
      Text("No incomplete todos")
        .font(.title3)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 180)
    .padding()
  }

  private func errorView(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Unable to load todos", systemImage: "exclamationmark.triangle")
        .font(.headline)
      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
    .padding(12)
  }

  private var footer: some View {
    HStack(spacing: 8) {
      if let loginItemMessage = model.loginItemMessage {
        Label(loginItemMessage, systemImage: "exclamationmark.triangle")
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      } else {
        Label("Starts at login", systemImage: "power")
          .font(.callout)
          .foregroundStyle(.tertiary)
      }
      Spacer(minLength: 12)
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .buttonStyle(.plain)
      .font(.callout)
    }
    .padding(12)
  }
}
