// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "pi-todo",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "TodoCore", targets: ["TodoCore"]),
    .executable(name: "todoctl", targets: ["todoctl"]),
    .executable(name: "TodoBar", targets: ["TodoBar"]),
  ],
  targets: [
    .target(
      name: "TodoCore",
      linkerSettings: [.linkedLibrary("sqlite3")]
    ),
    .executableTarget(
      name: "todoctl",
      dependencies: ["TodoCore"]
    ),
    .executableTarget(
      name: "TodoBar",
      dependencies: ["TodoCore"],
      linkerSettings: [.linkedFramework("ServiceManagement")]
    ),
    .testTarget(
      name: "TodoCoreTests",
      dependencies: ["TodoCore"]
    ),
  ],
  swiftLanguageModes: [.v5]
)
