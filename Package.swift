// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MouseClicker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MouseClicker", path: "Sources/MouseClicker")
    ]
)
