// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MarkdownMath",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "MarkdownMathParser", targets: ["MarkdownMathParser"]),
        .library(name: "MarkdownMathUI", targets: ["MarkdownMathUI"]),
        .library(name: "MarkdownMathHighlight", targets: ["MarkdownMathHighlight"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.5.0"),
        .package(url: "https://github.com/mgriebling/SwiftMath.git", from: "1.7.3"),
    ],
    targets: [
        .target(
            name: "MarkdownMathParser",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "MarkdownMathUI",
            dependencies: [
                "MarkdownMathParser",
                .product(name: "SwiftMath", package: "SwiftMath"),
            ]
        ),
        .target(
            name: "MarkdownMathHighlight",
            dependencies: [
                "MarkdownMathUI",
            ]
        ),
        .testTarget(
            name: "MarkdownMathParserTests",
            dependencies: ["MarkdownMathParser"]
        ),
        .testTarget(
            name: "MarkdownMathUITests",
            dependencies: ["MarkdownMathUI"]
        ),
    ]
)
