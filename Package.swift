// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoEditor",
    platforms: [.iOS(.v17), .visionOS(.v1)],
    products: [
        .library(
            name: "VideoEditor",
            targets: ["VideoEditor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/noppefoxwolf/AVFoundationBackport-iOS17", from: "0.0.1")
    ],
    targets: [
        .target(
            name: "VideoEditor",
            dependencies: [
                "AVFoundationBackport-iOS17"
            ]
        ),
        .testTarget(
            name: "VideoEditorTests",
            dependencies: ["VideoEditor"]
        ),
    ]
)
