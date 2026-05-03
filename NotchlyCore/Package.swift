// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NotchlyCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotchlyCore", targets: ["NotchlyCore"]),
    ],
    targets: [
        .target(name: "NotchlyCore"),
        .testTarget(name: "NotchlyCoreTests", dependencies: ["NotchlyCore"]),
    ]
)
