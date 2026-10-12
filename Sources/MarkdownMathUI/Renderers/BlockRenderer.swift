import SwiftUI
import MarkdownMathParser

/// Renders a single `BlockNode` into a SwiftUI view.
struct BlockRenderer: View {
    let block: BlockNode
    @Environment(\.markdownTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch block {
        case .heading(let level, let inlines):
            HeadingView(level: level, inlines: inlines, theme: theme, isDarkMode: colorScheme == .dark)

        case .paragraph(let inlines):
            InlineRenderer(theme: theme, isDarkMode: colorScheme == .dark).render(inlines)
                .font(theme.bodyFont)
                .foregroundStyle(theme.textColor)

        case .codeBlock(let language, let code):
            CodeBlockRenderer(language: language, code: code)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Code block\(language.map { ", \($0)" } ?? "")")

        case .blockquote(let blocks):
            BlockquoteView(blocks: blocks, theme: theme)

        case .orderedList(let start, let items):
            ListRenderer(ordered: true, start: start, items: items)

        case .unorderedList(let items):
            ListRenderer(ordered: false, start: 1, items: items)

        case .table(let header, let rows):
            TableRenderer(header: header, rows: rows)

        case .thematicBreak:
            Rectangle()
                .fill(theme.thematicBreakColor)
                .frame(height: 1)

        case .image(let source, let alt):
            ImageBlockView(source: source, alt: alt)

        case .displayLaTeX(let content):
            LaTeXView(latex: content, displayStyle: true)
                .accessibilityLabel(LaTeXAccessibility.describe(content))
        }
    }
}

// MARK: - Heading

private struct HeadingView: View {
    let level: Int
    let inlines: [InlineNode]
    let theme: MarkdownTheme
    let isDarkMode: Bool

    var body: some View {
        InlineRenderer(theme: theme, isDarkMode: isDarkMode).render(inlines)
            .font(headingFont)
            .bold(level <= 3)
            .foregroundStyle(theme.textColor)
            .padding(.top, theme.headingSpacing)
            .accessibilityAddTraits(.isHeader)
    }

    private var headingFont: Font {
        switch level {
        case 1: return theme.heading1Font
        case 2: return theme.heading2Font
        case 3: return theme.heading3Font
        case 4: return theme.heading4Font
        case 5: return theme.heading5Font
        default: return theme.heading6Font
        }
    }
}

// MARK: - Blockquote

private struct BlockquoteView: View {
    let blocks: [BlockNode]
    let theme: MarkdownTheme

    var body: some View {
        HStack(alignment: .top, spacing: theme.blockquoteIndent) {
            Rectangle()
                .fill(theme.blockquoteBorderColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, childBlock in
                    BlockRenderer(block: childBlock)
                }
            }
            .foregroundStyle(theme.blockquoteTextColor)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Image Block

private struct ImageBlockView: View {
    let source: String
    let alt: String

    var body: some View {
        if let url = URL(string: source) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Label(alt.isEmpty ? "Image failed to load" : alt, systemImage: "photo")
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .accessibilityLabel(alt)
        }
    }
}

