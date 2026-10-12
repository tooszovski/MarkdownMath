import SwiftUI
import SwiftMath
import MarkdownMathParser

/// Renders an array of `InlineNode` into a single concatenated `Text` view.
@MainActor
struct InlineRenderer {
    let theme: MarkdownTheme
    let isDarkMode: Bool

    init(theme: MarkdownTheme, isDarkMode: Bool = false) {
        self.theme = theme
        self.isDarkMode = isDarkMode
    }

    func render(_ inlines: [InlineNode]) -> Text {
        inlines.reduce(Text("")) { result, node in
            result + renderNode(node)
        }
    }

    private func renderNode(_ node: InlineNode) -> Text {
        switch node {
        case .text(let string):
            return Text(string)
        case .bold(let children):
            return render(children).bold()
        case .italic(let children):
            return render(children).italic()
        case .strikethrough(let children):
            return render(children).strikethrough()
        case .code(let code):
            return Text(code)
                .font(theme.codeFont)
                .foregroundStyle(theme.codeTextColor)
        case .link(let destination, let children):
            // Use markdown attributed string for tappable links
            let label = plainText(children)
            return Text(.init("[\(label)](\(destination))"))
                .foregroundStyle(theme.linkColor)
        case .image(_, let alt):
            return Text("[\(alt)]")
        case .inlineLaTeX(let content):
            if let image = renderInlineLaTeX(content) {
                return Text(image)
            } else {
                return Text(content)
                    .font(theme.codeFont)
                    .foregroundStyle(theme.textColor)
            }
        case .lineBreak:
            return Text("\n")
        case .softBreak:
            return Text(" ")
        }
    }

    /// Render inline LaTeX to a SwiftUI Image suitable for Text interpolation.
    private func renderInlineLaTeX(_ latex: String) -> Image? {
        let textColor: MTColor
        #if canImport(UIKit)
        textColor = UIColor(theme.textColor)
        #elseif canImport(AppKit)
        textColor = NSColor(theme.textColor)
        #endif

        return LaTeXRenderer.renderImage(
            latex,
            fontSize: 16,
            textColor: textColor,
            displayStyle: false,
            isDarkMode: isDarkMode
        )
    }

    /// Extract plain text from inline nodes for link labels.
    private func plainText(_ inlines: [InlineNode]) -> String {
        inlines.map { node in
            switch node {
            case .text(let string):
                return string
            case .bold(let children), .italic(let children),
                 .strikethrough(let children), .link(_, let children):
                return plainText(children)
            case .code(let code):
                return code
            case .image(_, let alt):
                return alt
            case .inlineLaTeX(let content):
                return LaTeXAccessibility.describe(content)
            case .lineBreak:
                return "\n"
            case .softBreak:
                return " "
            }
        }.joined()
    }
}
