// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoEditor",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .visionOS(.v2)],
    products: [
        .library(
            name: "VideoEditor",
            targets: ["VideoEditor"]
        ),
    ],
    targets: [
        .target(
            name: "VideoEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VideoEditorTests",
            dependencies: ["VideoEditor"]
        ),
    ]
)
