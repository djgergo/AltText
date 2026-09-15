// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "AltText",
    platforms: [
        .macOS(.v27),
        .iOS(.v27)
    ],
    products: [
        .executable(name: "AltText", targets: ["AltText"])
    ],
    targets: [
        .executableTarget(
            name: "AltText",
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "AltTextTests",
            dependencies: ["AltText"]
        )
    ]
)
