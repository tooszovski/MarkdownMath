import SwiftUI

// MARK: - Code Highlighter Environment

/// The closure signature for a pluggable syntax highlighter.
///
/// A code highlighter receives the raw code string, an optional language identifier,
/// and the current color scheme, then returns an `AttributedString` with syntax colors applied.
///
/// MarkdownMathHighlight provides a default implementation via
/// ``SwiftUICore/View/enableCodeHighlighting()``.
public typealias CodeHighlighterFunction = @MainActor @Sendable (String, String?, ColorScheme) -> AttributedString

struct CodeHighlighterKey: EnvironmentKey {
    static let defaultValue: CodeHighlighterFunction? = nil
}

extension EnvironmentValues {
    /// An optional code highlighter closure injected by the MarkdownMathHighlight target.
    ///
    /// When `nil` (the default), code blocks render as plain monospaced text.
    /// Call ``SwiftUICore/View/enableCodeHighlighting()`` from MarkdownMathHighlight
    /// to populate this value.
    public var codeHighlighter: CodeHighlighterFunction? {
        get { self[CodeHighlighterKey.self] }
        set { self[CodeHighlighterKey.self] = newValue }
    }
}
