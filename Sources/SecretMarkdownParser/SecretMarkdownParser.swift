import Markdown

/// The main entry point for parsing Markdown text that may contain embedded LaTeX formulas.
///
/// `SecretMarkdownParser` converts a Markdown string into a ``ParsedDocument`` AST
/// (abstract syntax tree) consisting of ``BlockNode`` and ``InlineNode`` values.
/// LaTeX delimiters (`$...$`, `$$...$$`, `\(...\)`, `\[...\]`) are recognized
/// and preserved as dedicated node types.
///
/// ## Usage
///
/// ```swift
/// let doc = SecretMarkdownParser.parse("Hello **world** and $E = mc^2$")
/// // doc.blocks contains paragraph with bold + inline LaTeX nodes
/// ```
///
/// ## Algorithm
///
/// 1. **Pre-pass** -- extract LaTeX blocks and replace with UUID placeholders
/// 2. **Parse** -- feed preprocessed Markdown into Apple's swift-markdown
/// 3. **Convert** -- transform swift-markdown AST into ``BlockNode``/``InlineNode``
/// 4. **Post-pass** -- replace UUID placeholders with LaTeX nodes
public enum SecretMarkdownParser {

    /// The current version of the SecretMarkdownParser library.
    public static let version = "0.1.0"

    /// Parse a Markdown string (possibly containing LaTeX) into a typed AST.
    ///
    /// This is the primary API for converting raw Markdown text into a structured
    /// ``ParsedDocument``. The returned document can be rendered by SecretMarkdownUI
    /// or inspected programmatically.
    ///
    /// - Parameter markdown: A Markdown string, optionally containing LaTeX delimiters.
    /// - Returns: A ``ParsedDocument`` containing the parsed block-level nodes.
    public static func parse(_ markdown: String) -> ParsedDocument {
        // 1. Extract LaTeX
        let extraction = LaTeXExtractor.extract(from: markdown)

        // 2. Parse with swift-markdown
        let document = Document(parsing: extraction.processedString)

        // 3. Convert to our AST
        let blocks = MarkupConverter.convert(document: document)

        // 4. Replace placeholders with LaTeX nodes
        let finalBlocks = LaTeXReplacer.replaceInBlocks(blocks, mapping: extraction.mapping)

        return ParsedDocument(blocks: finalBlocks)
    }
}
