// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownMathDemo",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(path: ".."),  // MarkdownMath
    ],
    targets: [
        .executableTarget(
            name: "MarkdownMathDemo",
            dependencies: [
                .product(name: "MarkdownMathUI", package: "MarkdownMath"),
                .product(name: "MarkdownMathHighlight", package: "MarkdownMath"),
            ]
        )
    ]
)
