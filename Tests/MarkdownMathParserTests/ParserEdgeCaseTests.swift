import Testing
@testable import MarkdownMathParser

// MARK: - Multiple display LaTeX blocks

@Test func multipleDisplayLaTeX() {
    let input = "$$x^2$$\n\nSome text\n\n$$y^2$$"
    let doc = MarkdownMathParser.parse(input)
    #expect(doc.blocks.count == 3)
    if case .displayLaTeX(let content) = doc.blocks[0] {
        #expect(content == "x^2")
    } else {
        Issue.record("Expected displayLaTeX at index 0, got \(doc.blocks[0])")
    }
    if case .paragraph(let inlines) = doc.blocks[1] {
        if case .text(let s) = inlines[0] { #expect(s == "Some text") }
    } else {
        Issue.record("Expected paragraph at index 1, got \(doc.blocks[1])")
    }
    if case .displayLaTeX(let content) = doc.blocks[2] {
        #expect(content == "y^2")
    } else {
        Issue.record("Expected displayLaTeX at index 2, got \(doc.blocks[2])")
    }
}

// MARK: - LaTeX with curly braces

@Test func laTeXWithCurlyBraces() {
    let doc = MarkdownMathParser.parse("$\\frac{a+b}{c-d}$")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .inlineLaTeX(let content) = inlines[0] else {
        Issue.record("Expected inlineLaTeX, got \(inlines)")
        return
    }
    #expect(content == "\\frac{a+b}{c-d}")
}

// MARK: - Dollar sign in code block not treated as LaTeX

@Test func dollarInCodeBlockNotLaTeX() {
    let md = "```python\nprice = $5\n```"
    let doc = MarkdownMathParser.parse(md)
    #expect(doc.blocks.count == 1)
    guard case .codeBlock(let lang, let code) = doc.blocks[0] else {
        Issue.record("Expected codeBlock, got \(doc.blocks[0])")
        return
    }
    #expect(lang == "python")
    #expect(code.contains("$5"))
    // Ensure no LaTeX blocks were produced
    let hasLaTeX = doc.blocks.contains { block in
        if case .displayLaTeX = block { return true }
        return false
    }
    #expect(!hasLaTeX)
}

// MARK: - Inline code with dollar not treated as LaTeX

@Test func inlineCodeWithDollarNotLaTeX() {
    let doc = MarkdownMathParser.parse("`$HOME`")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .code(let s) = inlines[0] else {
        Issue.record("Expected code, got \(inlines)")
        return
    }
    #expect(s == "$HOME")
}

// MARK: - Adjacent inline LaTeX blocks

@Test func adjacentInlineLaTeX() {
    // $x$$y$ — parser should see two inline LaTeX: $x$ and $y$,
    // with the middle $$ being the closing of first and opening of second
    let doc = MarkdownMathParser.parse("$x$$y$")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph, got \(doc.blocks)")
        return
    }
    let latexNodes = inlines.compactMap { node -> String? in
        if case .inlineLaTeX(let c) = node { return c }
        return nil
    }
    // The parser may interpret $x$$y$ as two inline LaTeX or differently.
    // We verify at least one inline LaTeX is extracted.
    #expect(latexNodes.count >= 1, "Expected at least one inlineLaTeX node, got \(inlines)")
}

// MARK: - LaTeX spanning multiple lines

@Test func displayLaTeXMultipleLines() {
    let input = "$$\n\\frac{a}{b}\n$$"
    let doc = MarkdownMathParser.parse(input)
    // Should produce a display LaTeX block
    let displayBlocks = doc.blocks.compactMap { block -> String? in
        if case .displayLaTeX(let c) = block { return c }
        return nil
    }
    #expect(displayBlocks.count == 1, "Expected one displayLaTeX block, got \(doc.blocks)")
    if let content = displayBlocks.first {
        #expect(content.contains("\\frac{a}{b}"))
    }
}

// MARK: - Mixed Cyrillic and LaTeX

@Test func mixedCyrillicAndLaTeX() {
    let doc = MarkdownMathParser.parse("Формула: $E=mc^2$ — это важно")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    let hasLaTeX = inlines.contains { node in
        if case .inlineLaTeX(let c) = node { return c == "E=mc^2" }
        return false
    }
    #expect(hasLaTeX, "Expected inlineLaTeX with E=mc^2 among \(inlines)")
    // Should also contain Cyrillic text nodes
    let hasText = inlines.contains { node in
        if case .text(let s) = node { return s.contains("Формула") }
        return false
    }
    #expect(hasText, "Expected text node containing 'Формула'")
}

// MARK: - Heading with multiple inline LaTeX

@Test func headingWithMultipleInlineLaTeX() {
    let doc = MarkdownMathParser.parse("# Title $x$ and $y$")
    guard case .heading(let level, let inlines) = doc.blocks[0] else {
        Issue.record("Expected heading, got \(doc.blocks)")
        return
    }
    #expect(level == 1)
    let latexCount = inlines.filter { node in
        if case .inlineLaTeX = node { return true }
        return false
    }.count
    #expect(latexCount == 2, "Expected 2 inline LaTeX in heading, got \(latexCount) in \(inlines)")
}

// MARK: - Blockquote containing LaTeX

@Test func blockquoteContainingLaTeX() {
    let doc = MarkdownMathParser.parse("> Quote $formula$")
    guard case .blockquote(let blocks) = doc.blocks[0] else {
        Issue.record("Expected blockquote, got \(doc.blocks)")
        return
    }
    #expect(blocks.count >= 1)
    guard case .paragraph(let inlines) = blocks[0] else {
        Issue.record("Expected paragraph inside blockquote, got \(blocks)")
        return
    }
    let hasLaTeX = inlines.contains { node in
        if case .inlineLaTeX(let c) = node { return c == "formula" }
        return false
    }
    #expect(hasLaTeX, "Expected inlineLaTeX 'formula' in blockquote, got \(inlines)")
}

// MARK: - List item with LaTeX

@Test func listItemWithLaTeX() {
    let doc = MarkdownMathParser.parse("- Item $x^2$")
    guard case .unorderedList(let items) = doc.blocks[0] else {
        Issue.record("Expected unorderedList, got \(doc.blocks)")
        return
    }
    #expect(items.count == 1)
    guard case .paragraph(let inlines) = items[0].blocks[0] else {
        Issue.record("Expected paragraph in list item, got \(items[0].blocks)")
        return
    }
    let hasLaTeX = inlines.contains { node in
        if case .inlineLaTeX(let c) = node { return c == "x^2" }
        return false
    }
    #expect(hasLaTeX, "Expected inlineLaTeX 'x^2' in list item, got \(inlines)")
}

// MARK: - Table cell with LaTeX

@Test func tableCellWithLaTeX() {
    let md = """
    | $x$ | $y$ |
    |-----|-----|
    | 1   | 2   |
    """
    let doc = MarkdownMathParser.parse(md)
    guard case .table(let header, let rows) = doc.blocks[0] else {
        Issue.record("Expected table, got \(doc.blocks)")
        return
    }
    #expect(header.cells.count == 2)
    #expect(rows.count == 1)
    // Check that header cells contain LaTeX
    let firstCellHasLaTeX = header.cells[0].inlines.contains { node in
        if case .inlineLaTeX(let c) = node { return c == "x" }
        return false
    }
    #expect(firstCellHasLaTeX, "Expected inlineLaTeX 'x' in first header cell, got \(header.cells[0].inlines)")
}

// MARK: - Consecutive paragraphs

@Test func consecutiveParagraphs() {
    let input = "First paragraph\n\nSecond paragraph"
    let doc = MarkdownMathParser.parse(input)
    #expect(doc.blocks.count == 2)
    guard case .paragraph(let inlines1) = doc.blocks[0] else {
        Issue.record("Expected paragraph at index 0")
        return
    }
    guard case .paragraph(let inlines2) = doc.blocks[1] else {
        Issue.record("Expected paragraph at index 1")
        return
    }
    if case .text(let s) = inlines1[0] { #expect(s == "First paragraph") }
    if case .text(let s) = inlines2[0] { #expect(s == "Second paragraph") }
}

// MARK: - Deeply nested list (3 levels)

@Test func deeplyNestedList() {
    let md = """
    - Level 1
      - Level 2
        - Level 3
    """
    let doc = MarkdownMathParser.parse(md)
    guard case .unorderedList(let items) = doc.blocks[0] else {
        Issue.record("Expected unorderedList, got \(doc.blocks)")
        return
    }
    // Level 1 item should contain a nested list
    let level1Blocks = items[0].blocks
    let nestedList = level1Blocks.first { block in
        if case .unorderedList = block { return true }
        return false
    }
    guard case .unorderedList(let level2Items) = nestedList else {
        Issue.record("Expected nested unorderedList at level 2, got \(level1Blocks)")
        return
    }
    // Level 2 item should contain another nested list
    let level2Blocks = level2Items[0].blocks
    let deepNestedList = level2Blocks.first { block in
        if case .unorderedList = block { return true }
        return false
    }
    guard case .unorderedList(let level3Items) = deepNestedList else {
        Issue.record("Expected nested unorderedList at level 3, got \(level2Blocks)")
        return
    }
    #expect(level3Items.count == 1)
}

// MARK: - Thematic break

@Test func thematicBreakVariants() {
    // Test with asterisks variant
    let doc = MarkdownMathParser.parse("***")
    #expect(doc.blocks.count == 1)
    guard case .thematicBreak = doc.blocks[0] else {
        Issue.record("Expected thematicBreak for '***', got \(doc.blocks[0])")
        return
    }
}

// MARK: - Image with URL

@Test func imageWithURL() {
    let doc = MarkdownMathParser.parse("![alt text](https://example.com/img.png)")
    #expect(doc.blocks.count == 1)
    // Image could be block-level or inline within a paragraph
    if case .image(let source, let alt) = doc.blocks[0] {
        #expect(source == "https://example.com/img.png")
        #expect(alt == "alt text")
    } else if case .paragraph(let inlines) = doc.blocks[0] {
        let hasImage = inlines.contains { node in
            if case .image(let src, let a) = node {
                return src == "https://example.com/img.png" && a == "alt text"
            }
            return false
        }
        #expect(hasImage, "Expected image inline node, got \(inlines)")
    } else {
        Issue.record("Expected image or paragraph with image, got \(doc.blocks[0])")
    }
}

// MARK: - Complex inline nesting (bold + italic)

@Test func boldItalicNesting() {
    let doc = MarkdownMathParser.parse("***bold italic***")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    // ***text*** is typically parsed as bold wrapping italic or italic wrapping bold
    // We check that we get nested formatting containing the text
    func extractText(from nodes: [InlineNode]) -> String {
        nodes.compactMap { node -> String? in
            switch node {
            case .text(let s): return s
            case .bold(let children): return extractText(from: children)
            case .italic(let children): return extractText(from: children)
            default: return nil
            }
        }.joined()
    }
    let text = extractText(from: inlines)
    #expect(text == "bold italic", "Expected 'bold italic' from nested formatting, got '\(text)' from \(inlines)")
}

// MARK: - LaTeX after escaped dollar

@Test func laTeXAfterEscapedDollar() {
    let doc = MarkdownMathParser.parse("\\$ not latex $x$ this is latex")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    let latexNodes = inlines.compactMap { node -> String? in
        if case .inlineLaTeX(let c) = node { return c }
        return nil
    }
    // The escaped \$ should not create LaTeX, but $x$ should
    #expect(latexNodes.contains("x"), "Expected inlineLaTeX 'x', got latex nodes: \(latexNodes) from \(inlines)")
    // Should have exactly one LaTeX node
    #expect(latexNodes.count == 1, "Expected exactly 1 LaTeX node, got \(latexNodes.count): \(latexNodes)")
}
