// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YaHome",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "YaHome",
            path: "Sources/YaHome"
        )
    ]
)
