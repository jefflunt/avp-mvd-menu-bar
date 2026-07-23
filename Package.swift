// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AVPMVDMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AVPMVDMenuBar", targets: ["AVPMVDMenuBar"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AVPMVDCore",
            dependencies: [],
            path: "Sources",
            exclude: ["AVPMVDMenuBarApp.swift"],
            sources: ["AVPMVDWatcher.swift"]
        ),
        .executableTarget(
            name: "AVPMVDMenuBar",
            dependencies: ["AVPMVDCore"],
            path: "Sources",
            exclude: ["AVPMVDWatcher.swift"],
            sources: ["AVPMVDMenuBarApp.swift"]
        ),
        .testTarget(
            name: "AVPMVDMenuBarTests",
            dependencies: ["AVPMVDCore"],
            path: "Tests"
        )
    ]
)
