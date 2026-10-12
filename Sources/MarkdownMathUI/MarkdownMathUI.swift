import SwiftUI

/// The MarkdownMathUI module renders Markdown with LaTeX support as native SwiftUI views.
///
/// The primary entry point is ``MarkdownView``, which accepts a Markdown string
/// and renders it using theme-aware SwiftUI views. LaTeX formulas are rendered
/// via ``LaTeXRenderer`` using CoreGraphics (no JavaScript).
///
/// ## Topics
///
/// ### Views
/// - ``MarkdownView``
///
/// ### Theming
/// - ``MarkdownTheme``
/// - ``CodeTheme``
///
/// ### LaTeX
/// - ``LaTeXRenderer``
/// - ``LaTeXCache``
public enum MarkdownMathUI {
    /// The current version of the MarkdownMathUI library.
    public static let version = "0.1.0"
}
