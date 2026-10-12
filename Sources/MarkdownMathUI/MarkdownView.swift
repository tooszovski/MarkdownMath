import SwiftUI
import MarkdownMathParser

/// A SwiftUI view that renders a Markdown string -- with optional LaTeX -- as native views.
///
/// `MarkdownView` supports two rendering modes:
///
/// - **Static** -- `MarkdownView("# Hello")` parses the string once at initialization.
/// - **Streaming** -- `MarkdownView(text: viewModel.text, isStreaming: true)` incrementally
///   reparses as `text` changes, buffering unclosed delimiters for smooth rendering
///   during AI chat token streaming.
///
/// ## Theming
///
/// Use the ``SwiftUICore/View/markdownTheme(_:)-1lkpf`` modifier to customize fonts, colors, and spacing:
///
/// ```swift
/// MarkdownView(content)
///     .markdownTheme(.compact)
/// ```
///
/// ## Code Highlighting
///
/// Import `MarkdownMathHighlight` and call `.enableCodeHighlighting()` to add
/// syntax highlighting to fenced code blocks.
public struct MarkdownView: View {
    private let document: ParsedDocument?
    private let streamingText: String?
    private let isStreaming: Bool

    @Environment(\.markdownTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var streamingParser = StreamingParser()
    @State private var streamingDocument: ParsedDocument?

    // MARK: - Static rendering

    /// Create a markdown view by parsing the given string once.
    ///
    /// Use this initializer when the Markdown content is known upfront and will not change.
    ///
    /// - Parameter markdown: The Markdown string to render.
    public init(_ markdown: String) {
        self.document = MarkdownMathParser.parse(markdown)
        self.streamingText = nil
        self.isStreaming = false
    }

    /// Create a markdown view from a pre-parsed document.
    ///
    /// Use this initializer when you have already parsed the Markdown (e.g., on a
    /// background thread) and want to avoid re-parsing.
    ///
    /// - Parameter document: A previously parsed ``ParsedDocument``.
    public init(document: ParsedDocument) {
        self.document = document
        self.streamingText = nil
        self.isStreaming = false
    }

    // MARK: - Streaming rendering

    /// Create a streaming markdown view.
    ///
    /// - Parameters:
    ///   - text: The full accumulated text so far. Pass the entire string on each update.
    ///   - isStreaming: Whether new text is still arriving. When `false`, the final parse is performed
    ///     without delimiter buffering.
    public init(text: String, isStreaming: Bool = false) {
        self.document = nil
        self.streamingText = text
        self.isStreaming = isStreaming
    }

    public var body: some View {
        let activeDocument = resolveDocument()
        VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
            ForEach(Array(activeDocument.blocks.enumerated()), id: \.offset) { _, block in
                BlockRenderer(block: block)
            }
        }
        .onChange(of: streamingText) { _, newValue in
            guard let text = newValue else { return }
            if reduceMotion {
                // Instant updates — no animations for accessibility
                if isStreaming {
                    streamingDocument = streamingParser.setText(text)
                } else {
                    streamingDocument = MarkdownMathParser.parse(text)
                }
            } else {
                if isStreaming {
                    streamingDocument = streamingParser.setText(text)
                } else {
                    // Streaming finished — do a full parse without delimiter buffering
                    streamingDocument = MarkdownMathParser.parse(text)
                }
            }
        }
        .onChange(of: isStreaming) { _, newIsStreaming in
            // When streaming ends, do a final full parse
            if !newIsStreaming, let text = streamingText {
                streamingDocument = MarkdownMathParser.parse(text)
            }
        }
        .onAppear {
            // Initial parse for streaming mode
            if let text = streamingText {
                if isStreaming {
                    streamingDocument = streamingParser.setText(text)
                } else {
                    streamingDocument = MarkdownMathParser.parse(text)
                }
            }
        }
    }

    // MARK: - Private

    private func resolveDocument() -> ParsedDocument {
        if let document {
            return document
        }
        if let streamingDocument {
            return streamingDocument
        }
        return ParsedDocument(blocks: [])
    }
}
