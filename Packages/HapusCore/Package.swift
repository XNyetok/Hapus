// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HapusCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HapusCore", targets: ["HapusCore"])
    ],
    targets: [
        .target(name: "HapusCore"),
        .testTarget(name: "HapusCoreTests", dependencies: ["HapusCore"]),
    ]
)
