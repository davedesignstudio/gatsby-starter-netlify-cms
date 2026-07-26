// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StoreCartKart",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .iOSApplication(
            name: "StoreCartKart",
            targets: ["AppModule"],
            bundleIdentifier: "com.cursor.storecartkart",
            teamIdentifier: "0000000000",
            displayVersion: "1.0",
            bundleVersion: "1",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor",
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
