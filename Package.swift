// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SnappyDB",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
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
