// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoEditor",
    platforms: [.iOS(.v16), .visionOS(.v1)],
    products: [
        .library(
            name: "VideoEditor",
            targets: ["VideoEditor"]
        ),
    ],
    targets: [
        .target(
            name: "VideoEditor"
        ),
        .testTarget(
            name: "VideoEditorTests",
            dependencies: ["VideoEditor"]
        ),
    ]
)
