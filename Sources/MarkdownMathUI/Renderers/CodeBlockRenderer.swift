import SwiftUI

/// Renders a fenced code block with optional language label, copy button, and syntax highlighting.
struct CodeBlockRenderer: View {
    let language: String?
    let code: String

    @Environment(\.markdownTheme) private var theme
    @Environment(\.codeTheme) private var codeTheme
    @Environment(\.codeHighlighter) private var codeHighlighter
    @Environment(\.colorScheme) private var colorScheme

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: language label + copy button
            HStack {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(codeTheme.languageLabelColor)
                }
                Spacer()
                copyButton
            }
            .padding(.horizontal, codeTheme.padding)
            .padding(.top, codeTheme.padding)
            .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                highlightedCodeView
                    .font(codeTheme.font)
                    .padding(.horizontal, codeTheme.padding)
                    .padding(.vertical, 4)
                    .padding(.bottom, codeTheme.padding - 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(codeTheme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: codeTheme.cornerRadius))
    }

    // MARK: - Highlighted Code

    @ViewBuilder
    private var highlightedCodeView: some View {
        if let highlighter = codeHighlighter {
            Text(highlighter(code, language, colorScheme))
        } else {
            Text(code)
                .foregroundStyle(codeTheme.textColor)
        }
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button {
            copyToClipboard(code)
            showCopied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showCopied = false
            }
        } label: {
            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .foregroundStyle(codeTheme.copyButtonColor)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("Copy code")
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
