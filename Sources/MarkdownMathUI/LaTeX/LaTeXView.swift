import SwiftUI
import SwiftMath
@_spi(Internal) import MarkdownMathParser

/// A SwiftUI view that renders a LaTeX formula with caching, fallback, and proper layout.
struct LaTeXView: View {
    let latex: String
    let displayStyle: Bool

    @Environment(\.markdownTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isDark = colorScheme == .dark
        let baseFontSize: CGFloat = displayStyle ? 20 : 16
        let fontSize = scaledFontSize(for: baseFontSize, dynamicTypeSize: dynamicTypeSize)
        let textColor = platformColor

        if let image = LaTeXRenderer.renderImage(
            latex,
            fontSize: fontSize,
            textColor: textColor,
            displayStyle: displayStyle,
            isDarkMode: isDark
        ) {
            if displayStyle {
                HStack {
                    Spacer()
                    image
                        .accessibilityLabel(LaTeXAccessibility.describe(latex))
                    Spacer()
                }
            } else {
                image
                    .accessibilityLabel(LaTeXAccessibility.describe(latex))
            }
        } else {
            // Fallback: show as code-style text. Emission lives in `.task(id:)`
            // so the warning fires once per distinct formula, not on every
            // re-evaluation of the view body.
            Text(latex)
                .font(theme.codeFont)
                .foregroundStyle(theme.textColor)
                .padding(displayStyle ? theme.codeBlockPadding : 0)
                .background(displayStyle ? theme.codeBlockBackgroundColor : .clear)
                .clipShape(RoundedRectangle(cornerRadius: displayStyle ? theme.codeBlockCornerRadius : 0))
                .task(id: latex) { emitFallback() }
        }
    }

    /// Emit `latexFallbackActivated` for the current formula.
    private func emitFallback() {
        let diagnostics = MarkdownDiagnostics.shared
        diagnostics.emit(
            severity: .warning,
            category: .rendering,
            code: .latexFallbackActivated,
            message: "LaTeX formula could not be rendered; falling back to code-style text.",
            context: MarkdownDiagnostic.Context(
                snippet: diagnostics.sanitizedSnippet(latex),
                location: nil,
                extra: ["displayStyle": String(displayStyle)]
            )
        )
    }

    private var platformColor: MTColor {
        #if canImport(UIKit)
        return UIColor(theme.textColor)
        #elseif canImport(AppKit)
        return NSColor(theme.textColor)
        #endif
    }

    /// Scale LaTeX font size based on Dynamic Type.
    private func scaledFontSize(for baseSize: CGFloat, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return baseSize * 0.8
        case .small: return baseSize * 0.9
        case .medium: return baseSize * 0.95
        case .large: return baseSize
        case .xLarge: return baseSize * 1.1
        case .xxLarge: return baseSize * 1.2
        case .xxxLarge: return baseSize * 1.3
        case .accessibility1: return baseSize * 1.5
        case .accessibility2: return baseSize * 1.7
        case .accessibility3: return baseSize * 1.9
        case .accessibility4: return baseSize * 2.1
        case .accessibility5: return baseSize * 2.3
        @unknown default: return baseSize
        }
    }
}
