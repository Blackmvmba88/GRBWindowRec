// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GRBWindowRec",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "GRBWindowRecApp", path: "Sources/LightCaptureApp")
    ]
)
