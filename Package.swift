// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MiniSignal",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MiniSignal",
            path: "Sources/MiniSignal"
        )
    ]
)
