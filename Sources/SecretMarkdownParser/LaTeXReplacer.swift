/// Post-pass: walks the AST, finds text nodes containing UUID placeholders,
/// splits them and inserts LaTeX nodes.
enum LaTeXReplacer {

    static func replaceInBlocks(_ blocks: [BlockNode], mapping: [String: LaTeXEntry]) -> [BlockNode] {
        guard !mapping.isEmpty else { return blocks }
        return blocks.map { replaceInBlock($0, mapping: mapping) }
    }

    // MARK: - Blocks

    private static func replaceInBlock(_ block: BlockNode, mapping: [String: LaTeXEntry]) -> BlockNode {
        switch block {
        case .heading(let level, let inlines):
            return .heading(level: level, inlines: replaceInInlines(inlines, mapping: mapping))

        case .paragraph(let inlines):
            let replaced = replaceInInlines(inlines, mapping: mapping)
            // Check if this paragraph is a single display LaTeX
            if replaced.count == 1, case .inlineLaTeX(let content) = replaced[0] {
                // Check if it was originally display
                if let entry = findEntryByContent(content, mapping: mapping), !entry.isInline {
                    return .displayLaTeX(content: content)
                }
            }
            // Also check for display LaTeX among mixed content
            return liftDisplayLaTeX(from: replaced, mapping: mapping)

        case .blockquote(let blocks):
            return .blockquote(blocks: replaceInBlocks(blocks, mapping: mapping))

        case .orderedList(let start, let items):
            return .orderedList(start: start, items: items.map { replaceInListItem($0, mapping: mapping) })

        case .unorderedList(let items):
            return .unorderedList(items: items.map { replaceInListItem($0, mapping: mapping) })

        case .table(let header, let rows):
            let newHeader = replaceInTableRow(header, mapping: mapping)
            let newRows = rows.map { replaceInTableRow($0, mapping: mapping) }
            return .table(header: newHeader, rows: newRows)

        case .codeBlock, .thematicBreak, .image, .displayLaTeX:
            return block
        }
    }

    private static func replaceInListItem(_ item: ListItem, mapping: [String: LaTeXEntry]) -> ListItem {
        return ListItem(
            blocks: replaceInBlocks(item.blocks, mapping: mapping),
            isChecked: item.isChecked
        )
    }

    private static func replaceInTableRow(_ row: TableRow, mapping: [String: LaTeXEntry]) -> TableRow {
        let cells = row.cells.map { cell in
            TableCell(inlines: replaceInInlines(cell.inlines, mapping: mapping))
        }
        return TableRow(cells: cells)
    }

    // MARK: - Inlines

    static func replaceInInlines(_ inlines: [InlineNode], mapping: [String: LaTeXEntry]) -> [InlineNode] {
        var result: [InlineNode] = []
        for inline in inlines {
            switch inline {
            case .text(let string):
                result.append(contentsOf: splitTextWithLaTeX(string, mapping: mapping))

            case .bold(let children):
                result.append(.bold(children: replaceInInlines(children, mapping: mapping)))

            case .italic(let children):
                result.append(.italic(children: replaceInInlines(children, mapping: mapping)))

            case .strikethrough(let children):
                result.append(.strikethrough(children: replaceInInlines(children, mapping: mapping)))

            case .link(let dest, let children):
                result.append(.link(destination: dest, children: replaceInInlines(children, mapping: mapping)))

            default:
                result.append(inline)
            }
        }
        return result
    }

    // MARK: - Text splitting

    private static func splitTextWithLaTeX(_ text: String, mapping: [String: LaTeXEntry]) -> [InlineNode] {
        var nodes: [InlineNode] = []
        var remaining = text

        while !remaining.isEmpty {
            // Find the earliest placeholder in remaining
            var earliest: (key: String, range: Range<String.Index>)?
            for key in mapping.keys {
                if let range = remaining.range(of: key) {
                    if earliest == nil || range.lowerBound < earliest!.range.lowerBound {
                        earliest = (key, range)
                    }
                }
            }

            guard let found = earliest, let entry = mapping[found.key] else {
                // No more placeholders
                if !remaining.isEmpty {
                    nodes.append(.text(remaining))
                }
                break
            }

            // Add text before placeholder
            let before = String(remaining[remaining.startIndex..<found.range.lowerBound])
            if !before.isEmpty {
                nodes.append(.text(before))
            }

            // Add LaTeX node
            if entry.isInline {
                nodes.append(.inlineLaTeX(content: entry.content))
            } else {
                // Display LaTeX in inline context — still use inlineLaTeX
                // The block-level promotion happens at the paragraph level
                nodes.append(.inlineLaTeX(content: entry.content))
            }

            remaining = String(remaining[found.range.upperBound...])
        }

        return nodes
    }

    // MARK: - Display LaTeX promotion

    /// If a paragraph consists solely of display LaTeX (possibly with whitespace),
    /// promote it to a `displayLaTeX` block.
    private static func liftDisplayLaTeX(from inlines: [InlineNode], mapping: [String: LaTeXEntry]) -> BlockNode {
        // Check if all non-whitespace inlines are display LaTeX
        let meaningful = inlines.filter { node in
            switch node {
            case .text(let s): return !s.allSatisfy(\.isWhitespace)
            case .softBreak, .lineBreak: return false
            default: return true
            }
        }

        if meaningful.count == 1,
           case .inlineLaTeX(let content) = meaningful[0],
           let entry = findEntryByContent(content, mapping: mapping),
           !entry.isInline {
            return .displayLaTeX(content: content)
        }

        return .paragraph(inlines: inlines)
    }

    private static func findEntryByContent(_ content: String, mapping: [String: LaTeXEntry]) -> LaTeXEntry? {
        return mapping.values.first { $0.content == content }
    }
}
