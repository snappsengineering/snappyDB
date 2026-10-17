// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnappyDB",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11)
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
