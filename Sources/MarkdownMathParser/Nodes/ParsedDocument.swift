/// A parsed Markdown+LaTeX document represented as a list of block-level nodes.
///
/// `ParsedDocument` is the top-level output of ``MarkdownMathParser/parse(_:)``
/// and ``StreamingParser``. It holds an ordered array of ``BlockNode`` values
/// that represent the document structure.
///
/// The type conforms to `Sendable`, so it can be safely passed across concurrency
/// boundaries (e.g., from a background parsing task to the main actor for rendering).
public struct ParsedDocument: Sendable {

    /// The top-level block nodes that make up the document.
    public let blocks: [BlockNode]

    /// Creates a parsed document from an array of block nodes.
    ///
    /// - Parameter blocks: The block-level nodes comprising the document.
    public init(blocks: [BlockNode]) {
        self.blocks = blocks
    }
}
