# Getting Started with MarkdownMath

Add MarkdownMath to your project and render Markdown with LaTeX in SwiftUI.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tooszovski/MarkdownMath.git", from: "0.1.0")
]
```

Then add `MarkdownMathUI` to your target's dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["MarkdownMathUI"]
)
```

## Basic Usage

```swift
import MarkdownMathUI

struct ContentView: View {
    var body: some View {
        MarkdownView("# Hello **World**\n\nEinstein's formula: $E = mc^2$")
    }
}
```

## Streaming (AI Chat)

Use the streaming initializer when text arrives incrementally from an API:

```swift
struct ChatBubble: View {
    @State var text = ""
    let isStreaming: Bool
    
    var body: some View {
        MarkdownView(text: text, isStreaming: isStreaming)
            .markdownTheme(.compact)
    }
}
```

The streaming parser buffers unclosed delimiters (LaTeX `$`, fenced code blocks)
so that partially received content renders cleanly without visual glitches.

## Custom Theme

Override fonts, colors, and spacing via the environment:

```swift
MarkdownView(content)
    .markdownTheme { theme in
        theme.bodyFont = .callout
        theme.codeBlockBackgroundColor = .gray.opacity(0.1)
    }
```

Or use a built-in preset:

```swift
MarkdownView(content)
    .markdownTheme(.compact)
```

## Code Highlighting

Import the optional `MarkdownMathHighlight` module and enable it with a view modifier:

```swift
import MarkdownMathHighlight

MarkdownView(content)
    .enableCodeHighlighting()
```

This activates regex-based syntax highlighting for Swift, Python, JavaScript,
TypeScript, Bash, SQL, Kotlin, JSON, HTML, and CSS.
