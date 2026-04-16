import SwiftUI
import SecretMarkdownUI

extension View {
    /// Enables syntax highlighting for fenced code blocks rendered by ``MarkdownView``.
    ///
    /// Apply this modifier to a ``MarkdownView`` (or any ancestor view) to activate
    /// the built-in regex-based ``CodeHighlighter``. Without this modifier, code blocks
    /// render as plain monospaced text.
    ///
    /// ```swift
    /// import SecretMarkdownHighlight
    ///
    /// MarkdownView(content)
    ///     .enableCodeHighlighting()
    /// ```
    ///
    /// - Returns: A view with syntax highlighting enabled in its environment.
    public func enableCodeHighlighting() -> some View {
        environment(\.codeHighlighter) { code, language, colorScheme in
            CodeHighlighter.highlight(code, language: language, colorScheme: colorScheme)
        }
    }
}
