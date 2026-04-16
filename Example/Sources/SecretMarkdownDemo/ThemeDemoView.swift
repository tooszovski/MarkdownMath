import SwiftUI
import SecretMarkdownUI
import SecretMarkdownHighlight

private let themePreviewMarkdown = """
# Theme Preview

A paragraph with **bold**, *italic*, and `code` formatting.

- First item
- Second item
  - Nested item

> A blockquote for emphasis.

```swift
let greeting = "Hello, World!"
```

Inline math $E = mc^2$ and display math:

$$\\sum_{k=0}^{n} \\binom{n}{k} = 2^n$$

| Column A | Column B |
|----------|----------|
| Value 1  | Value 2  |
"""

enum ThemeChoice: String, CaseIterable, Identifiable {
    case standard = "Default"
    case compact = "Compact"

    var id: String { rawValue }

    var theme: MarkdownTheme {
        switch self {
        case .standard: .default
        case .compact: .compact
        }
    }
}

struct ThemeDemoView: View {
    @State private var selectedTheme: ThemeChoice = .standard

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(ThemeChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                ScrollView {
                    MarkdownView(themePreviewMarkdown)
                        .markdownTheme(selectedTheme.theme)
                        .padding()
                        .animation(.default, value: selectedTheme)
                }
                .enableCodeHighlighting()
            }
            .navigationTitle("Themes")
        }
    }
}
