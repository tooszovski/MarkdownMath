import Foundation

/// Result of the LaTeX extraction pre-pass.
struct LaTeXExtraction: Sendable {
    let processedString: String
    let mapping: [String: LaTeXEntry]
}

/// A single extracted LaTeX block.
struct LaTeXEntry: Sendable {
    let content: String
    let isInline: Bool
}

/// Pre-pass: scans the input for LaTeX delimiters and replaces them with UUID placeholders.
/// Skips LaTeX inside backtick code spans and fenced code blocks.
enum LaTeXExtractor {

    static func extract(from input: String) -> LaTeXExtraction {
        var mapping: [String: LaTeXEntry] = [:]
        var result = ""
        result.reserveCapacity(input.count)

        let chars = Array(input.unicodeScalars)
        let count = chars.count
        var i = 0

        while i < count {
            // --- Fenced code block: ``` or ~~~
            if i < count - 2,
               (chars[i] == "`" && chars[i+1] == "`" && chars[i+2] == "`") ||
               (chars[i] == "~" && chars[i+1] == "~" && chars[i+2] == "~") {
                let fence = chars[i]
                // Count fence length
                var fenceLen = 0
                var j = i
                while j < count, chars[j] == fence { fenceLen += 1; j += 1 }
                // Copy opening fence + rest of line
                let fenceStart = i
                // Find end of opening fence line
                while j < count, chars[j] != "\n" { j += 1 }
                if j < count { j += 1 } // skip newline
                // Find closing fence
                var foundClose = false
                let searchStart = j
                while j < count {
                    // Check if line starts with matching fence
                    if chars[j] == fence {
                        var closeLen = 0
                        var k = j
                        while k < count, chars[k] == fence { closeLen += 1; k += 1 }
                        if closeLen >= fenceLen {
                            // Skip rest of closing fence line
                            while k < count, chars[k] != "\n" { k += 1 }
                            if k < count { k += 1 }
                            j = k
                            foundClose = true
                            break
                        }
                    }
                    // Skip to next line
                    while j < count, chars[j] != "\n" { j += 1 }
                    if j < count { j += 1 }
                }
                if !foundClose { j = count }
                for idx in fenceStart..<j {
                    result.append(Character(chars[idx]))
                }
                i = j
                continue
            }

            // --- Inline code span: `...`
            if chars[i] == "`" {
                // Count opening backticks
                var tickLen = 0
                var j = i
                while j < count, chars[j] == "`" { tickLen += 1; j += 1 }
                let start = i
                // Find matching closing backticks
                var found = false
                while j <= count - tickLen {
                    var match = true
                    for t in 0..<tickLen {
                        if chars[j + t] != "`" { match = false; break }
                    }
                    if match {
                        // Ensure it's exactly tickLen backticks (not more)
                        let afterClose = j + tickLen
                        if afterClose >= count || chars[afterClose] != "`" {
                            let end = j + tickLen
                            for idx in start..<end {
                                result.append(Character(chars[idx]))
                            }
                            i = end
                            found = true
                            break
                        }
                    }
                    j += 1
                }
                if !found {
                    // No closing found, just emit the backticks
                    for idx in start..<start + tickLen {
                        result.append(Character(chars[idx]))
                    }
                    i = start + tickLen
                }
                continue
            }

            // --- Escaped dollar: \$
            if chars[i] == "\\", i + 1 < count, chars[i+1] == "$" {
                result.append(Character(chars[i]))
                result.append(Character(chars[i+1]))
                i += 2
                continue
            }

            // --- Display LaTeX: $$...$$
            if chars[i] == "$", i + 1 < count, chars[i+1] == "$" {
                let contentStart = i + 2
                if let endIdx = findClosingDelimiter(in: chars, from: contentStart, delimiter: ["$", "$"]) {
                    let content = String(String.UnicodeScalarView(chars[contentStart..<endIdx]))
                    let uuid = "LATEX_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
                    mapping[uuid] = LaTeXEntry(content: content, isInline: false)
                    result.append(uuid)
                    i = endIdx + 2 // skip closing $$
                    continue
                }
                // No closing found, treat as literal
                result.append(Character(chars[i]))
                i += 1
                continue
            }

            // --- Display LaTeX: \[...\]
            if chars[i] == "\\", i + 1 < count, chars[i+1] == "[" {
                let contentStart = i + 2
                if let endIdx = findBackslashClosing(in: chars, from: contentStart, closer: "]") {
                    let content = String(String.UnicodeScalarView(chars[contentStart..<endIdx]))
                    let uuid = "LATEX_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
                    mapping[uuid] = LaTeXEntry(content: content, isInline: false)
                    result.append(uuid)
                    i = endIdx + 2 // skip \]
                    continue
                }
                result.append(Character(chars[i]))
                i += 1
                continue
            }

            // --- Inline LaTeX: \(...\)
            if chars[i] == "\\", i + 1 < count, chars[i+1] == "(" {
                let contentStart = i + 2
                if let endIdx = findBackslashClosing(in: chars, from: contentStart, closer: ")") {
                    let content = String(String.UnicodeScalarView(chars[contentStart..<endIdx]))
                    let uuid = "LATEX_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
                    mapping[uuid] = LaTeXEntry(content: content, isInline: true)
                    result.append(uuid)
                    i = endIdx + 2 // skip \)
                    continue
                }
                result.append(Character(chars[i]))
                i += 1
                continue
            }

            // --- Inline LaTeX: $...$  (not $$)
            if chars[i] == "$" {
                let contentStart = i + 1
                if let endIdx = findSingleDollarClose(in: chars, from: contentStart) {
                    let content = String(String.UnicodeScalarView(chars[contentStart..<endIdx]))
                    let uuid = "LATEX_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
                    mapping[uuid] = LaTeXEntry(content: content, isInline: true)
                    result.append(uuid)
                    i = endIdx + 1 // skip closing $
                    continue
                }
                result.append(Character(chars[i]))
                i += 1
                continue
            }

            // --- Regular character
            result.append(Character(chars[i]))
            i += 1
        }

        return LaTeXExtraction(processedString: result, mapping: mapping)
    }

    // MARK: - Helpers

    /// Find closing `$$` starting from `from`. Returns index of the first `$` of closing `$$`.
    private static func findClosingDelimiter(
        in chars: [Unicode.Scalar],
        from: Int,
        delimiter: [Character]
    ) -> Int? {
        let count = chars.count
        var j = from
        while j < count - 1 {
            if chars[j] == "$", chars[j+1] == "$" {
                return j
            }
            j += 1
        }
        return nil
    }

    /// Find `\closer` (e.g. `\]` or `\)`) starting from `from`. Returns index of the `\`.
    private static func findBackslashClosing(
        in chars: [Unicode.Scalar],
        from: Int,
        closer: Unicode.Scalar
    ) -> Int? {
        let count = chars.count
        var j = from
        while j < count - 1 {
            if chars[j] == "\\", chars[j+1] == closer {
                return j
            }
            j += 1
        }
        return nil
    }

    /// Find closing single `$` (not `$$`) starting from `from`. Returns index of closing `$`.
    private static func findSingleDollarClose(
        in chars: [Unicode.Scalar],
        from: Int
    ) -> Int? {
        let count = chars.count
        // Don't match empty $$ or content starting with space
        guard from < count else { return nil }

        var j = from
        while j < count {
            if chars[j] == "\\" {
                j += 2 // skip escaped char
                continue
            }
            if chars[j] == "$" {
                // Make sure it's not $$ (which is display)
                if j + 1 < count, chars[j+1] == "$" {
                    return nil
                }
                // Don't allow empty content
                if j == from { return nil }
                return j
            }
            // Don't span across newlines for inline
            if chars[j] == "\n" {
                // Allow single newline but not double
                if j + 1 < count, chars[j+1] == "\n" {
                    return nil
                }
            }
            j += 1
        }
        return nil
    }
}
