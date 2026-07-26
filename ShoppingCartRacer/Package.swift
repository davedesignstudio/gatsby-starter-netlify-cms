// swift-tools-version:5.9
import PackageDescription

// CartRacerKit holds the entire game simulation and is deliberately free of any
// Apple-framework dependencies, so the whole race can be run headlessly in tests
// on any platform Swift supports.
let package = Package(
    name: "CartRacerKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "CartRacerKit", targets: ["CartRacerKit"]),
        .executable(name: "race-lab", targets: ["RaceLab"])
    ],
    targets: [
        .target(name: "CartRacerKit", path: "Sources/CartRacerKit"),
        .executableTarget(name: "RaceLab", dependencies: ["CartRacerKit"], path: "Sources/RaceLab"),
        .testTarget(
            name: "CartRacerKitTests",
            dependencies: ["CartRacerKit"],
            path: "Tests/CartRacerKitTests"
        )
    ]
)
