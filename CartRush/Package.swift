// swift-tools-version: 5.9
// Sources are meant to be dropped into an Xcode iOS App target.
// See README.md for setup. This package is a convenience for browsing sources.
import PackageDescription

let package = Package(
    name: "CartRush",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "CartRushCore", targets: ["CartRushCore"])
    ],
    targets: [
        .target(
            name: "CartRushCore",
            path: "Sources/CartRush",
            exclude: ["CartRushApp.swift", "ContentView.swift"]
        )
    ]
)
