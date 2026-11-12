// swift-tools-version: 5.9

// Swift Playgrounds-app. Öppna mappen Sophamtning.swiftpm i Swift Playgrounds
// på iPad (eller i Xcode på Mac).

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Sophamtning",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Sophämtning",
            targets: ["AppModule"],
            bundleIdentifier: "se.privat.sophamtning",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .calendar),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [
                .pad,
                .phone
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
            path: "."
        )
    ]
)
