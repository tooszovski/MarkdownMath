// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SecretMarkdownDemo",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(path: ".."),  // SecretMarkdown
    ],
    targets: [
        .executableTarget(
            name: "SecretMarkdownDemo",
            dependencies: [
                .product(name: "SecretMarkdownUI", package: "SecretMarkdown"),
                .product(name: "SecretMarkdownHighlight", package: "SecretMarkdown"),
            ]
        )
    ]
)
