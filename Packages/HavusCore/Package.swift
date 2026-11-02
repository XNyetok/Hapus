// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HavusCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HavusCore", targets: ["HavusCore"])
    ],
    targets: [
        .target(name: "HavusCore"),
        .testTarget(name: "HavusCoreTests", dependencies: ["HavusCore"]),
    ]
)
