// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DynamicIslandCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DynamicIslandCore", targets: ["DynamicIslandCore"]),
    ],
    targets: [
        .target(name: "DynamicIslandCore"),
        .testTarget(name: "DynamicIslandCoreTests", dependencies: ["DynamicIslandCore"]),
    ]
)
