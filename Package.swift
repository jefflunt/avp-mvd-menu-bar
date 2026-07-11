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
        .executableTarget(
            name: "AVPMVDMenuBar",
            dependencies: [],
            path: "Sources"
        )
    ]
)
