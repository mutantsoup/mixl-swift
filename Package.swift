// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mixl",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Mixl",
            targets: ["Mixl"]
        ),
        .library(
            name: "MixlTesting",
            targets: ["MixlTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "Mixl",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "MixlTesting",
            dependencies: ["Mixl"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MixlTests",
            dependencies: ["Mixl", "MixlTesting"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "MixlExamples",
            dependencies: ["Mixl"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)
