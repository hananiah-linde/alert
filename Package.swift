// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Alert",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Alert",
            path: "Sources/Alert"
        )
    ]
)
