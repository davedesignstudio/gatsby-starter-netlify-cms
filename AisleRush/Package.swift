// swift-tools-version:5.9
import PackageDescription

// The simulation core is deliberately free of SpriteKit/UIKit so it builds and
// runs headless on any platform, which is what the test suite races on.
let package = Package(
    name: "AisleRush",
    products: [
        .library(name: "AisleRushCore", targets: ["AisleRushCore"])
    ],
    targets: [
        .target(name: "AisleRushCore"),
        .testTarget(name: "AisleRushCoreTests", dependencies: ["AisleRushCore"])
    ]
)
