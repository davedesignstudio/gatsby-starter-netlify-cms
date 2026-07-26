// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CartKart",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "CartKartCore", targets: ["CartKartCore"]),
        // Headless race simulator, handy for balancing without a Mac.
        .executable(name: "cartkart-sim", targets: ["CartKartSim"])
    ],
    targets: [
        .target(
            name: "CartKartCore",
            path: "Sources/CartKartCore"
        ),
        .executableTarget(
            name: "CartKartSim",
            dependencies: ["CartKartCore"],
            path: "Sources/CartKartSim"
        ),
        .testTarget(
            name: "CartKartCoreTests",
            dependencies: ["CartKartCore"],
            path: "Tests/CartKartCoreTests"
        )
    ]
)
