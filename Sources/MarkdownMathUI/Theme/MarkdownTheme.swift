import SwiftUI

/// Theme configuration for ``MarkdownView``.
///
/// `MarkdownTheme` controls fonts, colors, and spacing for all elements rendered
/// by ``MarkdownView``. It is a `Sendable` value type that can be injected into
/// the SwiftUI environment via ``SwiftUICore/View/markdownTheme(_:)-1lkpf``.
///
/// Two built-in presets are provided:
/// - ``default`` -- standard reading typography.
/// - ``compact`` -- smaller fonts and tighter spacing for chat bubbles.
public struct MarkdownTheme: Sendable {

    // MARK: - Fonts

    /// The font used for body text (paragraphs, list items).
    public var bodyFont: Font
    /// The font used for level-1 headings (`#`).
    public var heading1Font: Font
    /// The font used for level-2 headings (`##`).
    public var heading2Font: Font
    /// The font used for level-3 headings (`###`).
    public var heading3Font: Font
    /// The font used for level-4 headings (`####`).
    public var heading4Font: Font
    /// The font used for level-5 headings (`#####`).
    public var heading5Font: Font
    /// The font used for level-6 headings (`######`).
    public var heading6Font: Font
    /// The font used for inline code spans.
    public var codeFont: Font
    /// The font used inside fenced code blocks.
    public var codeBlockFont: Font

    // MARK: - Colors

    /// The primary text color for body content.
    public var textColor: Color
    /// The color used for hyperlinks.
    public var linkColor: Color
    /// The text color for inline code spans.
    public var codeTextColor: Color
    /// The background color for inline code spans.
    public var codeBackgroundColor: Color
    /// The background color for fenced code blocks.
    public var codeBlockBackgroundColor: Color
    /// The color of the vertical blockquote border.
    public var blockquoteBorderColor: Color
    /// The text color inside blockquotes.
    public var blockquoteTextColor: Color
    /// The border color for table rules.
    public var tableBorderColor: Color
    /// The background color for table header rows.
    public var tableHeaderBackgroundColor: Color
    /// The color of thematic break (horizontal rule) lines.
    public var thematicBreakColor: Color

    // MARK: - Spacing

    /// The vertical spacing between consecutive paragraphs or block elements.
    public var paragraphSpacing: CGFloat
    /// The top padding above headings.
    public var headingSpacing: CGFloat
    /// The leading indent for list items.
    public var listIndent: CGFloat
    /// The leading indent for blockquote content.
    public var blockquoteIndent: CGFloat
    /// The inner padding of fenced code blocks.
    public var codeBlockPadding: CGFloat
    /// The corner radius of fenced code block backgrounds.
    public var codeBlockCornerRadius: CGFloat

    // MARK: - Platform-adaptive secondary background

    /// A platform-adaptive secondary background color for use in code blocks and tables.
    ///
    /// Uses `UIColor.secondarySystemBackground` on iOS and
    /// `NSColor.controlBackgroundColor` on macOS.
    public static var secondaryBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    // MARK: - Memberwise Init

    /// Creates a markdown theme with the specified font, color, and spacing values.
    ///
    /// All parameters have sensible defaults based on standard system typography,
    /// semantic colors, and Dynamic Type support.
    public init(
        bodyFont: Font = .body,
        heading1Font: Font = .title,
        heading2Font: Font = .title2,
        heading3Font: Font = .title3,
        heading4Font: Font = .headline,
        heading5Font: Font = .headline,
        heading6Font: Font = .headline,
        codeFont: Font = .body.monospaced(),
        codeBlockFont: Font = .callout.monospaced(),
        textColor: Color = .primary,
        linkColor: Color = .accentColor,
        codeTextColor: Color = .secondary,
        codeBackgroundColor: Color = MarkdownTheme.secondaryBackgroundColor,
        codeBlockBackgroundColor: Color = MarkdownTheme.secondaryBackgroundColor,
        blockquoteBorderColor: Color = .secondary,
        blockquoteTextColor: Color = .secondary,
        tableBorderColor: Color = .secondary,
        tableHeaderBackgroundColor: Color = MarkdownTheme.secondaryBackgroundColor,
        thematicBreakColor: Color = .secondary,
        paragraphSpacing: CGFloat = 12,
        headingSpacing: CGFloat = 16,
        listIndent: CGFloat = 20,
        blockquoteIndent: CGFloat = 16,
        codeBlockPadding: CGFloat = 12,
        codeBlockCornerRadius: CGFloat = 8
    ) {
        self.bodyFont = bodyFont
        self.heading1Font = heading1Font
        self.heading2Font = heading2Font
        self.heading3Font = heading3Font
        self.heading4Font = heading4Font
        self.heading5Font = heading5Font
        self.heading6Font = heading6Font
        self.codeFont = codeFont
        self.codeBlockFont = codeBlockFont
        self.textColor = textColor
        self.linkColor = linkColor
        self.codeTextColor = codeTextColor
        self.codeBackgroundColor = codeBackgroundColor
        self.codeBlockBackgroundColor = codeBlockBackgroundColor
        self.blockquoteBorderColor = blockquoteBorderColor
        self.blockquoteTextColor = blockquoteTextColor
        self.tableBorderColor = tableBorderColor
        self.tableHeaderBackgroundColor = tableHeaderBackgroundColor
        self.thematicBreakColor = thematicBreakColor
        self.paragraphSpacing = paragraphSpacing
        self.headingSpacing = headingSpacing
        self.listIndent = listIndent
        self.blockquoteIndent = blockquoteIndent
        self.codeBlockPadding = codeBlockPadding
        self.codeBlockCornerRadius = codeBlockCornerRadius
    }

    // MARK: - Presets

    /// Standard reading typography with semantic colors for automatic dark/light mode support.
    public static var `default`: MarkdownTheme { MarkdownTheme() }

    /// Compact theme designed for chat bubble contexts with smaller fonts and reduced spacing.
    public static var compact: MarkdownTheme {
        MarkdownTheme(
            bodyFont: .callout,
            heading1Font: .headline,
            heading2Font: .subheadline,
            heading3Font: .subheadline,
            heading4Font: .callout.bold(),
            heading5Font: .callout.bold(),
            heading6Font: .callout.bold(),
            codeFont: .callout.monospaced(),
            codeBlockFont: .caption.monospaced(),
            paragraphSpacing: 8,
            headingSpacing: 10,
            listIndent: 16,
            blockquoteIndent: 12,
            codeBlockPadding: 8,
            codeBlockCornerRadius: 6
        )
    }
}
