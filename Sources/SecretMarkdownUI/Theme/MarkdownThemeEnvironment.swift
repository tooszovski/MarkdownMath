import SwiftUI

// MARK: - MarkdownTheme Environment

struct MarkdownThemeKey: EnvironmentKey {
    static let defaultValue: MarkdownTheme = .default
}

extension EnvironmentValues {
    /// The current ``MarkdownTheme`` used by ``MarkdownView`` and its sub-renderers.
    ///
    /// Set this value using the ``SwiftUICore/View/markdownTheme(_:)-1lkpf`` view modifier.
    public var markdownTheme: MarkdownTheme {
        get { self[MarkdownThemeKey.self] }
        set { self[MarkdownThemeKey.self] = newValue }
    }
}

// MARK: - CodeTheme Environment

struct CodeThemeKey: EnvironmentKey {
    static let defaultValue: CodeTheme = .default
}

extension EnvironmentValues {
    /// The current ``CodeTheme`` used for fenced code blocks inside ``MarkdownView``.
    ///
    /// Set this value using the ``SwiftUICore/View/codeTheme(_:)-9f7hy`` view modifier.
    public var codeTheme: CodeTheme {
        get { self[CodeThemeKey.self] }
        set { self[CodeThemeKey.self] = newValue }
    }
}

// MARK: - View Modifiers

extension View {

    /// Sets the markdown theme for this view and its descendants.
    ///
    /// - Parameter theme: The ``MarkdownTheme`` to apply.
    /// - Returns: A view with the updated markdown theme in its environment.
    public func markdownTheme(_ theme: MarkdownTheme) -> some View {
        environment(\.markdownTheme, theme)
    }

    /// Modifies the current markdown theme using a builder closure.
    ///
    /// This is useful for making incremental changes to the inherited theme
    /// without replacing it entirely.
    ///
    /// ```swift
    /// MarkdownView(content)
    ///     .markdownTheme { theme in
    ///         theme.bodyFont = .callout
    ///     }
    /// ```
    ///
    /// - Parameter modify: A closure that mutates the current ``MarkdownTheme``.
    /// - Returns: A view with the modified markdown theme.
    public func markdownTheme(_ modify: @escaping (inout MarkdownTheme) -> Void) -> some View {
        transformEnvironment(\.markdownTheme, transform: modify)
    }

    /// Sets the code theme for this view and its descendants.
    ///
    /// - Parameter theme: The ``CodeTheme`` to apply.
    /// - Returns: A view with the updated code theme in its environment.
    public func codeTheme(_ theme: CodeTheme) -> some View {
        environment(\.codeTheme, theme)
    }

    /// Modifies the current code theme using a builder closure.
    ///
    /// - Parameter modify: A closure that mutates the current ``CodeTheme``.
    /// - Returns: A view with the modified code theme.
    public func codeTheme(_ modify: @escaping (inout CodeTheme) -> Void) -> some View {
        transformEnvironment(\.codeTheme, transform: modify)
    }
}
