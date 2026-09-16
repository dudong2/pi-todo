import Foundation
import ServiceManagement

enum LoginItemManager {
  static func registerIfNeeded() -> String? {
    if ProcessInfo.processInfo.environment["TODO_BAR_DISABLE_LOGIN_ITEM"] == "1" {
      return nil
    }

    guard Bundle.main.bundleURL.pathExtension == "app" else {
      return "Install Todo Bar to enable automatic launch."
    }

    let service = SMAppService.mainApp
    switch service.status {
    case .enabled:
      return nil
    case .requiresApproval:
      return "Allow Todo Bar in System Settings → General → Login Items."
    case .notFound, .notRegistered:
      do {
        try service.register()
        if service.status == .requiresApproval {
          return "Allow Todo Bar in System Settings → General → Login Items."
        }
        return service.status == .enabled ? nil : "Todo Bar could not enable automatic launch."
      } catch {
        return "Automatic launch could not be enabled: \(error.localizedDescription)"
      }
    @unknown default:
      return "Todo Bar could not determine its automatic launch status."
    }
  }
}
