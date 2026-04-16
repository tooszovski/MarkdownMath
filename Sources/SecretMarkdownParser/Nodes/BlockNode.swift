/// A block-level node in the parsed Markdown document.
///
/// Each case represents a distinct block-level element such as headings, paragraphs,
/// code blocks, lists, tables, images, and LaTeX display formulas.
///
/// `BlockNode` is `Sendable` and can be freely shared across concurrency domains.
public enum BlockNode: Sendable {
    /// A heading with a level (1--6) and inline content.
    case heading(level: Int, inlines: [InlineNode])

    /// A paragraph containing inline nodes.
    case paragraph(inlines: [InlineNode])

    /// A fenced code block with an optional language identifier and the raw code string.
    case codeBlock(language: String?, code: String)

    /// A blockquote containing nested block nodes.
    case blockquote(blocks: [BlockNode])

    /// An ordered (numbered) list starting at a given index.
    case orderedList(start: Int, items: [ListItem])

    /// An unordered (bulleted) list.
    case unorderedList(items: [ListItem])

    /// A GFM-style table with a header row and zero or more data rows.
    case table(header: TableRow, rows: [TableRow])

    /// A thematic break (horizontal rule), typically rendered as `---` or `***`.
    case thematicBreak

    /// A standalone image with a source URL and alt text.
    case image(source: String, alt: String)

    /// A display-mode LaTeX formula (e.g., `$$...$$` or `\[...\]`), rendered as a centered block.
    case displayLaTeX(content: String)
}

/// A single item in an ordered or unordered list.
///
/// A list item may contain multiple block nodes (e.g., a paragraph followed by a nested list).
/// For task lists (GFM), ``isChecked`` indicates the checkbox state.
public struct ListItem: Sendable {

    /// The block-level content of this list item.
    public let blocks: [BlockNode]

    /// The task-list checkbox state.
    ///
    /// - `nil` -- not a task-list item.
    /// - `true` -- checked (`- [x]`).
    /// - `false` -- unchecked (`- [ ]`).
    public let isChecked: Bool?

    /// Creates a list item.
    ///
    /// - Parameters:
    ///   - blocks: The block-level content of the item.
    ///   - isChecked: The checkbox state, or `nil` if this is not a task-list item.
    public init(blocks: [BlockNode], isChecked: Bool? = nil) {
        self.blocks = blocks
        self.isChecked = isChecked
    }
}

/// A single row in a ``BlockNode/table(header:rows:)`` node.
public struct TableRow: Sendable {

    /// The cells that make up this row.
    public let cells: [TableCell]

    /// Creates a table row.
    ///
    /// - Parameter cells: The cells in the row.
    public init(cells: [TableCell]) {
        self.cells = cells
    }
}

/// A single cell in a ``TableRow``.
public struct TableCell: Sendable {

    /// The inline content of this cell.
    public let inlines: [InlineNode]

    /// Creates a table cell.
    ///
    /// - Parameter inlines: The inline nodes that form the cell content.
    public init(inlines: [InlineNode]) {
        self.inlines = inlines
    }
}
