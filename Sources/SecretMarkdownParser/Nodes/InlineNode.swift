/// An inline-level node in the parsed Markdown document.
///
/// Inline nodes represent text-level formatting such as bold, italic, links,
/// inline code, and inline LaTeX formulas. They appear inside block-level nodes
/// like ``BlockNode/paragraph(inlines:)`` and ``BlockNode/heading(level:inlines:)``.
///
/// `InlineNode` is `Sendable` and can be freely shared across concurrency domains.
public enum InlineNode: Sendable {
    /// Plain text content.
    case text(String)

    /// Bold (strong) text wrapping child inline nodes.
    case bold(children: [InlineNode])

    /// Italic (emphasis) text wrapping child inline nodes.
    case italic(children: [InlineNode])

    /// Strikethrough text wrapping child inline nodes.
    case strikethrough(children: [InlineNode])

    /// Inline code span (e.g., `` `code` ``).
    case code(String)

    /// A hyperlink with a destination URL and child inline nodes as the link label.
    case link(destination: String, children: [InlineNode])

    /// An inline image with a source URL and alt text.
    case image(source: String, alt: String)

    /// An inline LaTeX formula (e.g., `$x^2$` or `\(x^2\)`).
    case inlineLaTeX(content: String)

    /// A hard line break.
    case lineBreak

    /// A soft line break (typically rendered as a space).
    case softBreak
}
