// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SnappyDB",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27)
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
