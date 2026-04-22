// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PaletteKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PaletteKit",
            targets: ["PaletteKit"]
        ),
        // Uncomment when v2 Insights module lands (requires iOS 26+).
        // .library(
        //     name: "PaletteKitInsights",
        //     targets: ["PaletteKitInsights"]
        // ),
    ],
    targets: [
        .target(
            name: "PaletteKit",
            path: "Sources/PaletteKit",
            resources: [
                // Metal shader resources will be added here as they ship.
                // .process("Metal"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "PaletteKitTests",
            dependencies: ["PaletteKit"],
            path: "Tests/PaletteKitTests",
            resources: [
                .copy("Resources/goldens"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        // XCTest-Metrics based benchmarks live alongside the Swift Testing suite.
        // They stay opt-in via a separate scheme so CI can run them explicitly.
        .testTarget(
            name: "PaletteKitBenchmarks",
            dependencies: ["PaletteKit"],
            path: "Tests/PaletteKitBenchmarks",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
