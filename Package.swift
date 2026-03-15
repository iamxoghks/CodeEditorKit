// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodeEditorKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CodeEditorKit",
            targets: ["CodeEditorKit"]
        )
    ],
    targets: [
        .target(
            name: "CodeEditorKit"
        ),
        .testTarget(
            name: "CodeEditorKitTests",
            dependencies: ["CodeEditorKit"]
        )
    ]
)
