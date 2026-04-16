import Testing
@testable import SecretMarkdownParser

@Suite("StreamingParser")
struct StreamingParserTests {

    // MARK: - 1. Empty append

    @Test("append empty string returns empty document")
    func emptyAppend() {
        let parser = StreamingParser()
        let doc = parser.append("")
        #expect(doc.blocks.isEmpty)
    }

    // MARK: - 2. Append plain text incrementally

    @Test("incremental plain text appends produce correct document")
    func incrementalPlainText() {
        let parser = StreamingParser()
        _ = parser.append("Hello")
        let doc = parser.append(" world")
        #expect(parser.currentText == "Hello world")
        #expect(!doc.blocks.isEmpty)
        // Should contain a paragraph with text
        guard case .paragraph(let inlines) = doc.blocks.first else {
            Issue.record("Expected paragraph block")
            return
        }
        let fullText = inlines.compactMap { inline -> String? in
            if case .text(let t) = inline { return t }
            return nil
        }.joined()
        #expect(fullText.contains("Hello"))
        #expect(fullText.contains("world"))
    }

    // MARK: - 3. Unclosed inline LaTeX ($) buffers the tail

    @Test("unclosed $ buffers LaTeX as plain text")
    func unclosedInlineLaTeX() {
        let parser = StreamingParser()
        let doc = parser.append("Here is $x^2")
        #expect(parser.hasUnclosedDelimiters)
        // The unclosed $x^2 should appear as plain text, not as LaTeX
        let hasLaTeX = doc.blocks.contains { block in
            if case .paragraph(let inlines) = block {
                return inlines.contains { inline in
                    if case .inlineLaTeX = inline { return true }
                    return false
                }
            }
            return false
        }
        #expect(!hasLaTeX, "Unclosed LaTeX should not be rendered as LaTeX")
    }

    // MARK: - 4. Close the $ — now it becomes LaTeX

    @Test("closing $ converts buffered text to LaTeX")
    func closedInlineLaTeX() {
        let parser = StreamingParser()
        _ = parser.append("Here is $x^2")
        #expect(parser.hasUnclosedDelimiters)

        let doc = parser.append("$")
        #expect(!parser.hasUnclosedDelimiters)
        // Now the LaTeX should be properly parsed
        let hasLaTeX = doc.blocks.contains { block in
            if case .paragraph(let inlines) = block {
                return inlines.contains { inline in
                    if case .inlineLaTeX = inline { return true }
                    return false
                }
            }
            return false
        }
        #expect(hasLaTeX, "Closed LaTeX should be rendered as inlineLaTeX")
    }

    // MARK: - 5. Unclosed code block (```) buffers

    @Test("unclosed code block is buffered")
    func unclosedCodeBlock() {
        let parser = StreamingParser()
        let doc = parser.append("Some text\n```python\nprint('hello')\n")
        #expect(parser.hasUnclosedDelimiters)
        // Should NOT contain a codeBlock node (it's buffered)
        let hasCodeBlock = doc.blocks.contains { block in
            if case .codeBlock = block { return true }
            return false
        }
        #expect(!hasCodeBlock, "Unclosed code block should not be rendered as codeBlock")
    }

    // MARK: - 6. Unclosed $$ display LaTeX buffers

    @Test("unclosed $$ display LaTeX is buffered")
    func unclosedDisplayLaTeX() {
        let parser = StreamingParser()
        let doc = parser.append("Formula:\n$$\nx = \\frac{1}{2}\n")
        #expect(parser.hasUnclosedDelimiters)
        let hasDisplayLaTeX = doc.blocks.contains { block in
            if case .displayLaTeX = block { return true }
            return false
        }
        #expect(!hasDisplayLaTeX, "Unclosed display LaTeX should not be rendered")
    }

    // MARK: - 7. Multiple appends forming a complete document

    @Test("multiple appends build a complete document")
    func multipleAppends() {
        let parser = StreamingParser()
        _ = parser.append("# Title\n\n")
        _ = parser.append("Some paragraph with ")
        _ = parser.append("**bold** text.\n\n")
        let doc = parser.append("- item 1\n- item 2\n")

        #expect(parser.currentText == "# Title\n\nSome paragraph with **bold** text.\n\n- item 1\n- item 2\n")
        #expect(!parser.hasUnclosedDelimiters)

        // Should have heading, paragraph, and list
        let hasHeading = doc.blocks.contains { if case .heading = $0 { return true }; return false }
        let hasParagraph = doc.blocks.contains { if case .paragraph = $0 { return true }; return false }
        let hasList = doc.blocks.contains { if case .unorderedList = $0 { return true }; return false }
        #expect(hasHeading)
        #expect(hasParagraph)
        #expect(hasList)
    }

    // MARK: - 8. Reset clears state

    @Test("reset clears all accumulated state")
    func resetClearsState() {
        let parser = StreamingParser()
        _ = parser.append("Hello $x")
        #expect(parser.hasUnclosedDelimiters)
        #expect(!parser.currentText.isEmpty)

        parser.reset()
        #expect(parser.currentText.isEmpty)
        #expect(!parser.hasUnclosedDelimiters)
        #expect(parser.currentDocument.blocks.isEmpty)
    }

    // MARK: - 9. hasUnclosedDelimiters flag accuracy

    @Test("hasUnclosedDelimiters reports correctly for various states")
    func unclosedDelimitersFlag() {
        let parser = StreamingParser()

        // Plain text — no unclosed delimiters
        _ = parser.append("plain text")
        #expect(!parser.hasUnclosedDelimiters)

        // Add unclosed inline LaTeX
        parser.reset()
        _ = parser.append("value is $42")
        #expect(parser.hasUnclosedDelimiters)

        // Close it
        _ = parser.append("$")
        #expect(!parser.hasUnclosedDelimiters)

        // Unclosed display LaTeX
        parser.reset()
        _ = parser.append("$$x^2 + y^2")
        #expect(parser.hasUnclosedDelimiters)

        // Close it
        _ = parser.append("$$")
        #expect(!parser.hasUnclosedDelimiters)

        // Unclosed code block
        parser.reset()
        _ = parser.append("```\ncode")
        #expect(parser.hasUnclosedDelimiters)

        // Close it
        _ = parser.append("\n```\n")
        #expect(!parser.hasUnclosedDelimiters)
    }

    // MARK: - 10. Full streaming simulation

    @Test("full streaming simulation with LaTeX and code")
    func fullStreamingSimulation() {
        let parser = StreamingParser()

        // Simulate an AI response arriving chunk by chunk
        let chunks = [
            "The quadratic formula is ",
            "$x = \\frac{-b \\pm ",
            "\\sqrt{b^2 - 4ac}}{2a}$",
            "\n\nHere's a code example:\n\n",
            "```python\n",
            "import math\n",
            "def solve(a, b, c):\n",
            "    return (-b + math.sqrt(b**2 - 4*a*c)) / (2*a)\n",
            "```\n\n",
            "And display math:\n\n$$E = mc^2$$",
        ]

        // After chunk 0: plain text, no unclosed delimiters
        _ = parser.append(chunks[0])
        #expect(!parser.hasUnclosedDelimiters)

        // After chunk 1: unclosed inline LaTeX
        _ = parser.append(chunks[1])
        #expect(parser.hasUnclosedDelimiters)

        // After chunk 2: LaTeX is closed
        _ = parser.append(chunks[2])
        #expect(!parser.hasUnclosedDelimiters)

        // After chunk 3: paragraph break, still no unclosed
        _ = parser.append(chunks[3])
        #expect(!parser.hasUnclosedDelimiters)

        // After chunk 4: unclosed code block
        _ = parser.append(chunks[4])
        #expect(parser.hasUnclosedDelimiters)

        // Chunks 5-7: still unclosed code block
        _ = parser.append(chunks[5])
        _ = parser.append(chunks[6])
        _ = parser.append(chunks[7])
        #expect(parser.hasUnclosedDelimiters)

        // After chunk 8: code block closed
        _ = parser.append(chunks[8])
        #expect(!parser.hasUnclosedDelimiters)

        // After chunk 9: complete document
        let finalDoc = parser.append(chunks[9])
        #expect(!parser.hasUnclosedDelimiters)

        // Verify final document structure
        let hasInlineLaTeX = finalDoc.blocks.contains { block in
            if case .paragraph(let inlines) = block {
                return inlines.contains { if case .inlineLaTeX = $0 { return true }; return false }
            }
            return false
        }
        let hasCodeBlock = finalDoc.blocks.contains { if case .codeBlock = $0 { return true }; return false }
        let hasDisplayLaTeX = finalDoc.blocks.contains { if case .displayLaTeX = $0 { return true }; return false }

        #expect(hasInlineLaTeX, "Should contain inline LaTeX")
        #expect(hasCodeBlock, "Should contain code block")
        #expect(hasDisplayLaTeX, "Should contain display LaTeX")
    }

    // MARK: - 11. setText works like SwiftUI binding

    @Test("setText replaces full text and reparses")
    func setTextFullReplace() {
        let parser = StreamingParser()
        _ = parser.setText("Hello")
        #expect(parser.currentText == "Hello")

        let doc = parser.setText("Hello world")
        #expect(parser.currentText == "Hello world")
        #expect(!doc.blocks.isEmpty)
    }

    // MARK: - 12. currentDocument without appending

    @Test("currentDocument returns last parsed result")
    func currentDocumentProperty() {
        let parser = StreamingParser()
        let doc1 = parser.append("# Heading")
        let doc2 = parser.currentDocument
        #expect(doc1.blocks.count == doc2.blocks.count)
    }

    // MARK: - 13. Unclosed \\( inline LaTeX

    @Test("unclosed backslash-paren LaTeX is buffered")
    func unclosedBackslashParenLaTeX() {
        let parser = StreamingParser()
        _ = parser.append("Value is \\(x^2 + y")
        #expect(parser.hasUnclosedDelimiters)

        _ = parser.append("\\)")
        #expect(!parser.hasUnclosedDelimiters)
    }

    // MARK: - 14. Unclosed \\[ display LaTeX

    @Test("unclosed backslash-bracket LaTeX is buffered")
    func unclosedBackslashBracketLaTeX() {
        let parser = StreamingParser()
        _ = parser.append("Formula:\n\n\\[x = 1")
        #expect(parser.hasUnclosedDelimiters)

        let doc = parser.append("\\]")
        #expect(!parser.hasUnclosedDelimiters)
        // \[...\] on its own line should become displayLaTeX
        let hasDisplayLaTeX = doc.blocks.contains { if case .displayLaTeX = $0 { return true }; return false }
        #expect(hasDisplayLaTeX)
    }
}
