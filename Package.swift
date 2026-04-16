// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SecretMarkdown",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SecretMarkdownParser", targets: ["SecretMarkdownParser"]),
        .library(name: "SecretMarkdownUI", targets: ["SecretMarkdownUI"]),
        .library(name: "SecretMarkdownHighlight", targets: ["SecretMarkdownHighlight"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.5.0"),
        .package(name: "SwiftMath", path: "../SwiftMath"),
    ],
    targets: [
        .target(
            name: "SecretMarkdownParser",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "SecretMarkdownUI",
            dependencies: [
                "SecretMarkdownParser",
                .product(name: "SwiftMath", package: "SwiftMath"),
            ]
        ),
        .target(
            name: "SecretMarkdownHighlight",
            dependencies: [
                "SecretMarkdownUI",
            ]
        ),
        .testTarget(
            name: "SecretMarkdownParserTests",
            dependencies: ["SecretMarkdownParser"]
        ),
        .testTarget(
            name: "SecretMarkdownUITests",
            dependencies: ["SecretMarkdownUI"]
        ),
    ]
)
