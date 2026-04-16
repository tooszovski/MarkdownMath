import SwiftUI
import SecretMarkdownUI
import SecretMarkdownHighlight

private let sampleMarkdown = """
# Heading 1

## Heading 2

### Heading 3

This is a paragraph with **bold text**, *italic text*, ~~strikethrough~~, and `inline code`.

Here is a [link to Example](https://example.com) within a paragraph.

---

## Lists

### Unordered List

- First item
- Second item
  - Nested item A
  - Nested item B
- Third item

### Ordered List

1. Step one
2. Step two
   1. Sub-step 2.1
   2. Sub-step 2.2
3. Step three

### Task List

- [x] Completed task
- [ ] Pending task
- [x] Another completed task

## Blockquote

> This is a blockquote. It can span multiple lines and is commonly used \
> to highlight important information or quotations.

## Code Block

```swift
struct ContentView: View {
    @State private var count = 0

    var body: some View {
        Button("Tapped \\(count) times") {
            count += 1
        }
    }
}
```

## Table

| Feature | Status | Notes |
|---------|--------|-------|
| Markdown | Done | Full CommonMark support |
| LaTeX | Done | Inline and display math |
| Streaming | Done | Incremental parsing |

## Mathematics

Inline math: The famous equation $E = mc^2$ relates energy and mass.

Display math:

$$\\int_0^1 f(x)\\,dx = F(1) - F(0)$$

Another display formula:

$$\\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}$$
"""

struct StaticDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                MarkdownView(sampleMarkdown)
                    .padding()
            }
            .enableCodeHighlighting()
            .navigationTitle("Static Rendering")
        }
    }
}
