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
        .library(
            name: "PaletteKitInsights",
            targets: ["PaletteKitInsights"]
        ),
    ],
    targets: [
        .target(
            name: "PaletteKit",
            path: "Sources/PaletteKit",
            exclude: [
                "Metal/Histogram.metal",
            ],
            resources: [],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .target(
            name: "PaletteKitInsights",
            dependencies: ["PaletteKit"],
            path: "Sources/PaletteKitInsights",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "PaletteKitTests",
            dependencies: ["PaletteKit"],
            path: "Tests/PaletteKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "PaletteKitInsightsTests",
            dependencies: ["PaletteKitInsights"],
            path: "Tests/PaletteKitInsightsTests",
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
