// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GolfYardageCheatsheet",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GolfYardageCheatsheet",
            targets: ["GolfYardageCheatsheet"]
        )
    ],
    targets: [
        .target(name: "GolfYardageCheatsheet"),
        .testTarget(
            name: "GolfYardageCheatsheetTests",
            dependencies: ["GolfYardageCheatsheet"]
        )
    ]
)

