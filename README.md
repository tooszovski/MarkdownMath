# SecretMarkdown

Markdown rendering library with inline LaTeX support, optimized for AI chat interfaces with streaming output.

![Build & Test](https://github.com/nicktoozyakin/SecretMarkdown/actions/workflows/build-and-test.yml/badge.svg)

## Requirements

- Swift 6
- iOS 17+
- macOS 14+
- visionOS 1+

## Installation

Add SecretMarkdown as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nicktoozyakin/SecretMarkdown.git", from: "0.1.0"),
]
```

Then add the desired target to your module:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SecretMarkdownUI", package: "SecretMarkdown"),
    ]
)
```

### Available Products

| Product | Description |
|---|---|
| `SecretMarkdownParser` | Markdown to AST parser with LaTeX extraction |
| `SecretMarkdownUI` | SwiftUI renderer with theming and streaming |
| `SecretMarkdownHighlight` | Syntax highlighting (optional) |

## License

See LICENSE for details.
