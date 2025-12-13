// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-money",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MoneyKit",
            targets: ["MoneyKit"]
        ),
    ],
    targets: [
        .target(
            name: "MoneyKit",
            path: "Sources/MoneyKit",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MoneyKitTests",
            dependencies: ["MoneyKit"],
            path: "Tests/MoneyKitTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
