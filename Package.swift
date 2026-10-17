// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnappyDB",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "SnappyDB", targets: ["SnappyDB"]),
    ],
    targets: [
        .target(
            name: "SnappyDB",
            path: "Sources/SnappyDB",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SnappyDBTests",
            dependencies: ["SnappyDB"],
            path: "Tests/SnappyDBTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
