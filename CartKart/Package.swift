// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CartKart",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "CartKartCore", targets: ["CartKartCore"])
    ],
    targets: [
        .target(
            name: "CartKartCore",
            path: "Sources/CartKartCore"
        ),
        .testTarget(
            name: "CartKartCoreTests",
            dependencies: ["CartKartCore"],
            path: "Tests/CartKartCoreTests"
        )
    ]
)
