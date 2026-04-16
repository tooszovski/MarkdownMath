import SwiftUI
import SecretMarkdownParser

/// Renders ordered and unordered lists, including task list items.
struct ListRenderer: View {
    let ordered: Bool
    let start: Int
    let items: [ListItem]

    @Environment(\.markdownTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.paragraphSpacing * 0.5) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                ListItemView(
                    item: item,
                    bullet: bulletText(index: index, item: item)
                )
            }
        }
        .padding(.leading, theme.listIndent)
        .accessibilityElement(children: .contain)
    }

    private func bulletText(index: Int, item: ListItem) -> String {
        if let isChecked = item.isChecked {
            return isChecked ? "☑" : "☐"
        } else if ordered {
            return "\(start + index)."
        } else {
            return "•"
        }
    }
}

private struct ListItemView: View {
    let item: ListItem
    let bullet: String

    @Environment(\.markdownTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(bullet)
                .font(theme.bodyFont)
                .foregroundStyle(theme.textColor)

            VStack(alignment: .leading, spacing: theme.paragraphSpacing * 0.5) {
                ForEach(Array(item.blocks.enumerated()), id: \.offset) { _, block in
                    BlockRenderer(block: block)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
