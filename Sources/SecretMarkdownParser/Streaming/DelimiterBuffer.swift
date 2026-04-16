/// Tracks unclosed delimiters in streaming text.
enum DelimiterBuffer: Sendable {

    /// Check if text has unclosed delimiters at the end.
    /// Returns the first unclosed delimiter info, or nil if all delimiters are properly closed.
    static func findUnclosedDelimiter(in text: String) -> UnclosedDelimiter? {
        let chars = Array(text.unicodeScalars)
        let count = chars.count
        var i = 0

        // Track the last unclosed delimiter as we scan forward.
        // We replay the same logic LaTeXExtractor uses, but instead of replacing
        // we just track open/close state.

        var lastUnclosed: UnclosedDelimiter?

        while i < count {
            // --- Fenced code block: ``` (at least 3 backticks at line start)
            if isLineStart(chars, at: i),
               i + 2 < count,
               chars[i] == "`", chars[i + 1] == "`", chars[i + 2] == "`" {
                let fenceStart = i
                var fenceLen = 0
                var j = i
                while j < count, chars[j] == "`" { fenceLen += 1; j += 1 }
                // Skip rest of opening fence line
                while j < count, chars[j] != "\n" { j += 1 }
                if j < count { j += 1 }
                // Look for closing fence
                var foundClose = false
                while j < count {
                    if chars[j] == "`" {
                        var closeLen = 0
                        var k = j
                        while k < count, chars[k] == "`" { closeLen += 1; k += 1 }
                        if closeLen >= fenceLen {
                            while k < count, chars[k] != "\n" { k += 1 }
                            if k < count { k += 1 }
                            j = k
                            foundClose = true
                            break
                        }
                    }
                    while j < count, chars[j] != "\n" { j += 1 }
                    if j < count { j += 1 }
                }
                if !foundClose {
                    // Code block is unclosed — record it
                    let strIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: fenceStart)
                    lastUnclosed = UnclosedDelimiter(
                        type: .codeBlock,
                        startIndex: strIndex
                    )
                    return lastUnclosed
                }
                i = j
                continue
            }

            // --- Inline code span: backticks (skip over, they don't interact with LaTeX)
            if chars[i] == "`" {
                var tickLen = 0
                var j = i
                while j < count, chars[j] == "`" { tickLen += 1; j += 1 }
                // If this is 3+ backticks but not at line start, still just inline code
                // For delimiter tracking we only care about code blocks at line start
                // and inline code doesn't affect LaTeX delimiter tracking much,
                // but we skip through it
                var found = false
                while j <= count - tickLen {
                    var match = true
                    for t in 0..<tickLen {
                        if chars[j + t] != "`" { match = false; break }
                    }
                    if match {
                        let afterClose = j + tickLen
                        if afterClose >= count || chars[afterClose] != "`" {
                            i = j + tickLen
                            found = true
                            break
                        }
                    }
                    j += 1
                }
                if !found {
                    // Unclosed inline code
                    let strIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: i)
                    lastUnclosed = UnclosedDelimiter(type: .inlineCode, startIndex: strIndex)
                    return lastUnclosed
                }
                continue
            }

            // --- Escaped dollar
            if chars[i] == "\\", i + 1 < count, chars[i + 1] == "$" {
                i += 2
                continue
            }

            // --- Display LaTeX: $$
            if chars[i] == "$", i + 1 < count, chars[i + 1] == "$" {
                let blockStart = i
                let contentStart = i + 2
                var j = contentStart
                var foundClose = false
                while j < count - 1 {
                    if chars[j] == "$", chars[j + 1] == "$" {
                        foundClose = true
                        i = j + 2
                        break
                    }
                    j += 1
                }
                if !foundClose {
                    let strIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: blockStart)
                    lastUnclosed = UnclosedDelimiter(type: .displayLaTeX, startIndex: strIndex)
                    return lastUnclosed
                }
                continue
            }

            // --- Display LaTeX: \[...\]
            if chars[i] == "\\", i + 1 < count, chars[i + 1] == "[" {
                let blockStart = i
                let contentStart = i + 2
                var j = contentStart
                var foundClose = false
                while j < count - 1 {
                    if chars[j] == "\\", chars[j + 1] == "]" {
                        foundClose = true
                        i = j + 2
                        break
                    }
                    j += 1
                }
                if !foundClose {
                    let strIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: blockStart)
                    lastUnclosed = UnclosedDelimiter(type: .displayLaTeX, startIndex: strIndex)
                    return lastUnclosed
                }
                continue
            }

            // --- Inline LaTeX: \(...\)
            if chars[i] == "\\", i + 1 < count, chars[i + 1] == "(" {
                let blockStart = i
                let contentStart = i + 2
                var j = contentStart
                var foundClose = false
                while j < count - 1 {
                    if chars[j] == "\\", chars[j + 1] == ")" {
                        foundClose = true
                        i = j + 2
                        break
                    }
                    j += 1
                }
                if !foundClose {
                    let strIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: blockStart)
                    lastUnclosed = UnclosedDelimiter(type: .inlineLaTeX, startIndex: strIndex)
                    return lastUnclosed
                }
                continue
            }

            // --- Inline LaTeX: $...$
            if chars[i] == "$" {
                let blockStart = i
                let contentStart = i + 1
                // Use same rules as LaTeXExtractor
                guard contentStart < count else {
                    let strIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: blockStart)
                    lastUnclosed = UnclosedDelimiter(type: .inlineLaTeX, startIndex: strIndex)
                    return lastUnclosed
                }
                var j = contentStart
                var foundClose = false
                while j < count {
                    if chars[j] == "\\" {
                        j += 2
                        continue
                    }
                    if chars[j] == "$" {
                        if j + 1 < count, chars[j + 1] == "$" {
                            // This is $$, not a single $ close
                            break
                        }
                        if j == contentStart {
                            // Empty inline LaTeX, treat as literal $
                            break
                        }
                        foundClose = true
                        i = j + 1
                        break
                    }
                    if chars[j] == "\n", j + 1 < count, chars[j + 1] == "\n" {
                        break
                    }
                    j += 1
                }
                if !foundClose {
                    let strIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: blockStart)
                    lastUnclosed = UnclosedDelimiter(type: .inlineLaTeX, startIndex: strIndex)
                    return lastUnclosed
                }
                continue
            }

            i += 1
        }

        return lastUnclosed
    }

    // MARK: - Helpers

    private static func isLineStart(_ chars: [Unicode.Scalar], at index: Int) -> Bool {
        if index == 0 { return true }
        return chars[index - 1] == "\n"
    }
}

/// Information about an unclosed delimiter found during streaming.
///
/// Used by ``StreamingParser`` to determine where to split safe (parseable)
/// content from pending (incomplete) content.
public struct UnclosedDelimiter: Sendable {
    /// The kind of delimiter that was opened but not closed.
    public let type: DelimiterType

    /// The position in the source string where the unclosed delimiter begins.
    public let startIndex: String.Index
}

/// The kinds of delimiters that can be left unclosed during streaming.
///
/// ``StreamingParser`` uses this to decide how to buffer trailing content
/// while waiting for more chunks to arrive.
public enum DelimiterType: Sendable {
    /// An inline LaTeX delimiter: single `$...$` or `\(...\)`.
    case inlineLaTeX
    /// A display LaTeX delimiter: double `$$...$$` or `\[...\]`.
    case displayLaTeX
    /// A fenced code block opened with three or more backticks.
    case codeBlock
    /// An inline code span opened with one or more backticks.
    case inlineCode
}
