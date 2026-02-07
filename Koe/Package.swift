// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Koe",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Koe",
            dependencies: ["WhisperKit"],
            path: "Koe",
            exclude: ["Resources/Info.plist", "Resources/Koe.entitlements"],
            resources: [
                .copy("Resources/Assets.xcassets"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
            ]
        ),
    ]
)
