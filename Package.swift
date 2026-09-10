// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AltText",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
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
