// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WardrobeApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "WardrobeApp",
            targets: ["WardrobeApp"]),
    ],
    targets: [
        .target(
            name: "WardrobeApp",
            path: "WardrobeApp",
            resources: [
                .process("Resources"),
                .process("Assets.xcassets")
            ]
        ),
    ]
)
