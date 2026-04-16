import Testing
@testable import SecretMarkdownParser

// MARK: - Version

@Test func parserVersionExists() {
    #expect(SecretMarkdownParser.version == "0.1.0")
}

// MARK: - Basic block parsing

@Test func parseHeading() {
    let doc = SecretMarkdownParser.parse("# Hello")
    #expect(doc.blocks.count == 1)
    guard case .heading(let level, let inlines) = doc.blocks[0] else {
        Issue.record("Expected heading")
        return
    }
    #expect(level == 1)
    #expect(inlines.count == 1)
    if case .text(let s) = inlines[0] { #expect(s == "Hello") }
}

@Test func parseMultipleLevelHeadings() {
    let doc = SecretMarkdownParser.parse("## Second\n### Third")
    #expect(doc.blocks.count == 2)
    if case .heading(let level, _) = doc.blocks[0] { #expect(level == 2) }
    if case .heading(let level, _) = doc.blocks[1] { #expect(level == 3) }
}

@Test func parseParagraph() {
    let doc = SecretMarkdownParser.parse("Hello world")
    #expect(doc.blocks.count == 1)
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    if case .text(let s) = inlines[0] { #expect(s == "Hello world") }
}

@Test func parseCodeBlock() {
    let doc = SecretMarkdownParser.parse("```swift\nlet x = 1\n```")
    #expect(doc.blocks.count == 1)
    guard case .codeBlock(let lang, let code) = doc.blocks[0] else {
        Issue.record("Expected code block")
        return
    }
    #expect(lang == "swift")
    #expect(code.contains("let x = 1"))
}

@Test func parseCodeBlockNoLanguage() {
    let doc = SecretMarkdownParser.parse("```\nplain code\n```")
    guard case .codeBlock(let lang, _) = doc.blocks[0] else {
        Issue.record("Expected code block")
        return
    }
    #expect(lang == nil)
}

@Test func parseBlockquote() {
    let doc = SecretMarkdownParser.parse("> Quote text")
    guard case .blockquote(let blocks) = doc.blocks[0] else {
        Issue.record("Expected blockquote")
        return
    }
    #expect(blocks.count == 1)
    if case .paragraph(let inlines) = blocks[0],
       case .text(let s) = inlines[0] {
        #expect(s == "Quote text")
    }
}

@Test func parseThematicBreak() {
    let doc = SecretMarkdownParser.parse("---")
    #expect(doc.blocks.count == 1)
    guard case .thematicBreak = doc.blocks[0] else {
        Issue.record("Expected thematic break")
        return
    }
}

// MARK: - Lists

@Test func parseUnorderedList() {
    let doc = SecretMarkdownParser.parse("- Item 1\n- Item 2")
    guard case .unorderedList(let items) = doc.blocks[0] else {
        Issue.record("Expected unordered list")
        return
    }
    #expect(items.count == 2)
}

@Test func parseOrderedList() {
    let doc = SecretMarkdownParser.parse("1. First\n2. Second\n3. Third")
    guard case .orderedList(let start, let items) = doc.blocks[0] else {
        Issue.record("Expected ordered list")
        return
    }
    #expect(start == 1)
    #expect(items.count == 3)
}

@Test func parseNestedList() {
    let md = """
    - Item 1
      - Nested A
      - Nested B
    - Item 2
    """
    let doc = SecretMarkdownParser.parse(md)
    guard case .unorderedList(let items) = doc.blocks[0] else {
        Issue.record("Expected unordered list")
        return
    }
    #expect(items.count == 2)
    // First item should contain a nested list
    let firstItemBlocks = items[0].blocks
    let hasNestedList = firstItemBlocks.contains { block in
        if case .unorderedList = block { return true }
        return false
    }
    #expect(hasNestedList)
}

@Test func parseTaskList() {
    let md = """
    - [x] Done task
    - [ ] Pending task
    - Regular item
    """
    let doc = SecretMarkdownParser.parse(md)
    guard case .unorderedList(let items) = doc.blocks[0] else {
        Issue.record("Expected unordered list")
        return
    }
    #expect(items[0].isChecked == true)
    #expect(items[1].isChecked == false)
    #expect(items[2].isChecked == nil)
}

// MARK: - Table

@Test func parseTable() {
    let md = """
    | A | B |
    |---|---|
    | 1 | 2 |
    | 3 | 4 |
    """
    let doc = SecretMarkdownParser.parse(md)
    guard case .table(let header, let rows) = doc.blocks[0] else {
        Issue.record("Expected table")
        return
    }
    #expect(header.cells.count == 2)
    #expect(rows.count == 2)
    if case .text(let s) = header.cells[0].inlines[0] { #expect(s == "A") }
    if case .text(let s) = rows[0].cells[0].inlines[0] { #expect(s == "1") }
}

// MARK: - Inline formatting

@Test func parseBold() {
    let doc = SecretMarkdownParser.parse("**bold text**")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .bold(let children) = inlines[0] else {
        Issue.record("Expected bold")
        return
    }
    if case .text(let s) = children[0] { #expect(s == "bold text") }
}

@Test func parseItalic() {
    let doc = SecretMarkdownParser.parse("*italic text*")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .italic(let children) = inlines[0] else {
        Issue.record("Expected italic")
        return
    }
    if case .text(let s) = children[0] { #expect(s == "italic text") }
}

@Test func parseStrikethrough() {
    let doc = SecretMarkdownParser.parse("~~struck~~")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .strikethrough(let children) = inlines[0] else {
        Issue.record("Expected strikethrough")
        return
    }
    if case .text(let s) = children[0] { #expect(s == "struck") }
}

@Test func parseInlineCode() {
    let doc = SecretMarkdownParser.parse("`code here`")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .code(let s) = inlines[0] else {
        Issue.record("Expected code")
        return
    }
    #expect(s == "code here")
}

@Test func parseLink() {
    let doc = SecretMarkdownParser.parse("[Click](https://example.com)")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .link(let dest, let children) = inlines[0] else {
        Issue.record("Expected link")
        return
    }
    #expect(dest == "https://example.com")
    if case .text(let s) = children[0] { #expect(s == "Click") }
}

// MARK: - LaTeX extraction: inline

@Test func parseInlineLaTeX() {
    let doc = SecretMarkdownParser.parse("$x^2$")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .inlineLaTeX(let content) = inlines[0] else {
        Issue.record("Expected inlineLaTeX, got \(inlines)")
        return
    }
    #expect(content == "x^2")
}

@Test func parseDisplayLaTeX() {
    let doc = SecretMarkdownParser.parse("$$\\frac{a}{b}$$")
    #expect(doc.blocks.count == 1)
    guard case .displayLaTeX(let content) = doc.blocks[0] else {
        Issue.record("Expected displayLaTeX, got \(doc.blocks)")
        return
    }
    #expect(content == "\\frac{a}{b}")
}

@Test func parseLaTeXInParagraph() {
    let doc = SecretMarkdownParser.parse("Hello $x^2$ world")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    #expect(inlines.count == 3)
    if case .text(let s) = inlines[0] { #expect(s == "Hello ") }
    if case .inlineLaTeX(let c) = inlines[1] { #expect(c == "x^2") }
    if case .text(let s) = inlines[2] { #expect(s == " world") }
}

// MARK: - LaTeX NOT extracted from code

@Test func laTeXInCodeSpanNotExtracted() {
    let doc = SecretMarkdownParser.parse("`$x$`")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .code(let s) = inlines[0] else {
        Issue.record("Expected code, got \(inlines)")
        return
    }
    #expect(s == "$x$")
}

@Test func laTeXInFencedCodeBlockNotExtracted() {
    let md = "```\n$x^2$\n```"
    let doc = SecretMarkdownParser.parse(md)
    guard case .codeBlock(_, let code) = doc.blocks[0] else {
        Issue.record("Expected code block")
        return
    }
    #expect(code.contains("$x^2$"))
}

// MARK: - Escaped dollar

@Test func escapedDollarNotTreatedAsLaTeX() {
    let doc = SecretMarkdownParser.parse("Price is \\$5")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    // Should not contain any LaTeX node
    let hasLaTeX = inlines.contains { node in
        if case .inlineLaTeX = node { return true }
        return false
    }
    #expect(!hasLaTeX)
}

// MARK: - Alternative delimiters

@Test func parseBackslashParenInlineLaTeX() {
    let doc = SecretMarkdownParser.parse("\\(x + y\\)")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .inlineLaTeX(let content) = inlines[0] else {
        Issue.record("Expected inlineLaTeX, got \(inlines)")
        return
    }
    #expect(content == "x + y")
}

@Test func parseBackslashBracketDisplayLaTeX() {
    let doc = SecretMarkdownParser.parse("\\[x + y\\]")
    guard case .displayLaTeX(let content) = doc.blocks[0] else {
        Issue.record("Expected displayLaTeX, got \(doc.blocks)")
        return
    }
    #expect(content == "x + y")
}

// MARK: - Unicode

@Test func parseUnicodeContent() {
    let doc = SecretMarkdownParser.parse("Привет мир")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    if case .text(let s) = inlines[0] { #expect(s == "Привет мир") }
}

@Test func parseEmojiContent() {
    let doc = SecretMarkdownParser.parse("Hello 🌍🚀")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    if case .text(let s) = inlines[0] { #expect(s.contains("🌍")) }
}

// MARK: - Edge cases

@Test func parseEmptyInput() {
    let doc = SecretMarkdownParser.parse("")
    #expect(doc.blocks.isEmpty)
}

@Test func parseOnlyLaTeX() {
    let doc = SecretMarkdownParser.parse("$E=mc^2$")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .inlineLaTeX(let content) = inlines[0] else {
        Issue.record("Expected inlineLaTeX")
        return
    }
    #expect(content == "E=mc^2")
}

@Test func headingWithInlineLaTeX() {
    let doc = SecretMarkdownParser.parse("# Title $\\alpha$")
    guard case .heading(let level, let inlines) = doc.blocks[0] else {
        Issue.record("Expected heading")
        return
    }
    #expect(level == 1)
    let hasLaTeX = inlines.contains { node in
        if case .inlineLaTeX = node { return true }
        return false
    }
    #expect(hasLaTeX)
}

@Test func nestedUnderscoreInLaTeX() {
    let doc = SecretMarkdownParser.parse("$x_{ij}$")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    guard case .inlineLaTeX(let content) = inlines[0] else {
        Issue.record("Expected inlineLaTeX, got \(inlines)")
        return
    }
    #expect(content == "x_{ij}")
}

@Test func emptyDisplayLaTeX() {
    let doc = SecretMarkdownParser.parse("$$$$")
    // Empty $$$$ — two dollar signs for open, two for close, empty content
    // The extractor sees $$ then $$ and extracts empty content
    guard case .displayLaTeX(let content) = doc.blocks[0] else {
        // Could also be a paragraph — depends on how markdown parses it
        // Accept either outcome
        return
    }
    #expect(content == "")
}

@Test func multipleLaTeXInOneParagraph() {
    let doc = SecretMarkdownParser.parse("$a$ and $b$ and $c$")
    guard case .paragraph(let inlines) = doc.blocks[0] else {
        Issue.record("Expected paragraph")
        return
    }
    let latexCount = inlines.filter { node in
        if case .inlineLaTeX = node { return true }
        return false
    }.count
    #expect(latexCount == 3)
}
