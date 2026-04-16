import Markdown

/// Converts a swift-markdown `Document` AST into our own `[BlockNode]`.
enum MarkupConverter {

    static func convert(document: Document) -> [BlockNode] {
        return document.children.compactMap { convertBlock($0) }
    }

    // MARK: - Block conversion

    private static func convertBlock(_ markup: any Markup) -> BlockNode? {
        switch markup {
        case let heading as Heading:
            return .heading(level: heading.level, inlines: convertInlines(heading.inlineChildren))

        case let paragraph as Paragraph:
            return .paragraph(inlines: convertInlines(paragraph.inlineChildren))

        case let codeBlock as CodeBlock:
            let lang = codeBlock.language.flatMap { $0.isEmpty ? nil : $0 }
            return .codeBlock(language: lang, code: codeBlock.code)

        case let blockquote as BlockQuote:
            let blocks = blockquote.children.compactMap { convertBlock($0) }
            return .blockquote(blocks: blocks)

        case let orderedList as OrderedList:
            let items = Array(orderedList.listItems.map { convertListItem($0) })
            return .orderedList(start: Int(orderedList.startIndex), items: items)

        case let unorderedList as UnorderedList:
            let items = Array(unorderedList.listItems.map { convertListItem($0) })
            return .unorderedList(items: items)

        case let table as Markdown.Table:
            let header = convertTableRow(table.head)
            let rows = Array(table.body.rows.map { convertTableRow($0) })
            return .table(header: header, rows: rows)

        case is ThematicBreak:
            return .thematicBreak

        case let htmlBlock as HTMLBlock:
            return .paragraph(inlines: [.text(htmlBlock.rawHTML)])

        default:
            // Fallback: try to extract inline content
            return nil
        }
    }

    // MARK: - List items

    private static func convertListItem(_ item: Markdown.ListItem) -> ListItem {
        let checkbox = item.checkbox
        let isChecked: Bool?
        switch checkbox {
        case .checked: isChecked = true
        case .unchecked: isChecked = false
        case .none: isChecked = nil
        }
        let blocks = item.children.compactMap { convertBlock($0) }
        return ListItem(blocks: blocks, isChecked: isChecked)
    }

    // MARK: - Table

    private static func convertTableRow(_ head: Markdown.Table.Head) -> TableRow {
        let cells = Array(head.cells.map { cell in
            TableCell(inlines: convertInlines(cell.inlineChildren))
        })
        return TableRow(cells: cells)
    }

    private static func convertTableRow(_ row: Markdown.Table.Row) -> TableRow {
        let cells = Array(row.cells.map { cell in
            TableCell(inlines: convertInlines(cell.inlineChildren))
        })
        return TableRow(cells: cells)
    }

    // MARK: - Inline conversion

    static func convertInlines(_ children: some Sequence<any InlineMarkup>) -> [InlineNode] {
        return children.compactMap { convertInline($0) }
    }

    private static func convertInline(_ markup: any InlineMarkup) -> InlineNode? {
        switch markup {
        case let text as Markdown.Text:
            return .text(text.string)

        case let strong as Strong:
            return .bold(children: convertInlines(strong.inlineChildren))

        case let emphasis as Emphasis:
            return .italic(children: convertInlines(emphasis.inlineChildren))

        case let strikethrough as Strikethrough:
            return .strikethrough(children: convertInlines(strikethrough.inlineChildren))

        case let code as InlineCode:
            return .code(code.code)

        case let link as Markdown.Link:
            return .link(
                destination: link.destination ?? "",
                children: convertInlines(link.inlineChildren)
            )

        case let image as Markdown.Image:
            let alt = image.plainText
            return .image(source: image.source ?? "", alt: alt)

        case is LineBreak:
            return .lineBreak

        case is SoftBreak:
            return .softBreak

        case let html as InlineHTML:
            return .text(html.rawHTML)

        default:
            return nil
        }
    }
}

// MARK: - Helpers

private extension Markup {
    var inlineChildren: [any InlineMarkup] {
        children.compactMap { $0 as? (any InlineMarkup) }
    }
}
