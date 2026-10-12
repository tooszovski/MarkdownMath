import SwiftUI
import struct MarkdownMathParser.TableRow
import struct MarkdownMathParser.TableCell

/// Identifiable wrapper for indexed table cells.
private struct IndexedCell: Identifiable {
    let id: Int
    let cell: TableCell
}

/// Identifiable wrapper for indexed table rows.
private struct IndexedRow: Identifiable {
    let id: Int
    let row: TableRow
}

/// Renders a GFM-style table using `Grid` (iOS 16+).
struct TableRenderer: View {
    let header: TableRow
    let rows: [TableRow]

    @Environment(\.markdownTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var indexedHeaderCells: [IndexedCell] {
        header.cells.enumerated().map { IndexedCell(id: $0.offset, cell: $0.element) }
    }

    private var indexedRows: [IndexedRow] {
        rows.enumerated().map { IndexedRow(id: $0.offset, row: $0.element) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header row
                GridRow {
                    ForEach(indexedHeaderCells) { item in
                        InlineRenderer(theme: theme, isDarkMode: colorScheme == .dark).render(item.cell.inlines)
                            .font(theme.bodyFont)
                            .bold()
                            .foregroundStyle(theme.textColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                }
                .background(theme.tableHeaderBackgroundColor)

                Divider()
                    .background(theme.tableBorderColor)

                // Data rows
                ForEach(indexedRows) { indexedRow in
                    GridRow {
                        ForEach(
                            indexedRow.row.cells.enumerated().map {
                                IndexedCell(id: $0.offset, cell: $0.element)
                            }
                        ) { item in
                            InlineRenderer(theme: theme, isDarkMode: colorScheme == .dark).render(item.cell.inlines)
                                .font(theme.bodyFont)
                                .foregroundStyle(theme.textColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                    }

                    Divider()
                        .background(theme.tableBorderColor)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.tableBorderColor, lineWidth: 0.5)
            )
        }
    }
}
