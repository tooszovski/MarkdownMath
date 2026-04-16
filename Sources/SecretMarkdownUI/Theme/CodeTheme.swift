import SwiftUI

/// Theme configuration for fenced code blocks, kept separate from ``MarkdownTheme`` for modularity.
///
/// `CodeTheme` controls the font, colors, padding, corner radius, and UI chrome
/// (language label, copy button) of code blocks rendered by ``MarkdownView``.
/// Inject it via ``SwiftUICore/View/codeTheme(_:)-9f7hy``.
///
/// Two built-in presets are provided:
/// - ``default`` -- standard code block appearance.
/// - ``compact`` -- smaller font and tighter spacing for chat bubbles.
public struct CodeTheme: Sendable {

    /// The monospaced font used inside code blocks.
    public var font: Font
    /// The default text color for un-highlighted code.
    public var textColor: Color
    /// The background color of the code block container.
    public var backgroundColor: Color
    /// The inner padding of the code block container.
    public var padding: CGFloat
    /// The corner radius of the code block container.
    public var cornerRadius: CGFloat
    /// The color of the language label shown above the code.
    public var languageLabelColor: Color
    /// The color of the copy-to-clipboard button icon.
    public var copyButtonColor: Color

    // MARK: - Platform-adaptive secondary background

    /// A platform-adaptive secondary background color for code block backgrounds.
    public static var secondaryBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    // MARK: - Memberwise Init

    /// Creates a code theme with the specified appearance values.
    ///
    /// All parameters have sensible defaults using system monospaced fonts and semantic colors.
    public init(
        font: Font = .callout.monospaced(),
        textColor: Color = .primary,
        backgroundColor: Color = CodeTheme.secondaryBackgroundColor,
        padding: CGFloat = 12,
        cornerRadius: CGFloat = 8,
        languageLabelColor: Color = .secondary,
        copyButtonColor: Color = .secondary
    ) {
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.languageLabelColor = languageLabelColor
        self.copyButtonColor = copyButtonColor
    }

    // MARK: - Presets

    /// Standard code block appearance with semantic colors.
    public static var `default`: CodeTheme { CodeTheme() }

    /// Compact code theme designed for chat bubble contexts.
    public static var compact: CodeTheme {
        CodeTheme(
            font: .caption.monospaced(),
            padding: 8,
            cornerRadius: 6
        )
    }
}
