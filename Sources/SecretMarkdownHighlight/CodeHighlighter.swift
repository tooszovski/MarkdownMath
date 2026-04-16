import SwiftUI

// MARK: - Token Types

enum TokenType {
    case keyword
    case string
    case comment
    case number
    case type
    case jsonKey
    case tagName
    case attributeName
    case propertyName
}

// MARK: - Token

struct Token {
    let range: Range<String.Index>
    let type: TokenType
}

// MARK: - Color Palette

struct SyntaxColorPalette {
    let keyword: Color
    let string: Color
    let comment: Color
    let number: Color
    let type: Color

    static let light = SyntaxColorPalette(
        keyword: Color(red: 0.0, green: 0.2, blue: 0.7),       // #0033B3
        string: Color(red: 0.024, green: 0.49, blue: 0.09),    // #067D17
        comment: Color(red: 0.55, green: 0.55, blue: 0.55),    // #8C8C8C
        number: Color(red: 0.09, green: 0.314, blue: 0.922),   // #1750EB
        type: Color(red: 0.0, green: 0.384, blue: 0.478)       // #00627A
    )

    static let dark = SyntaxColorPalette(
        keyword: Color(red: 0.812, green: 0.557, blue: 0.427), // #CF8E6D
        string: Color(red: 0.416, green: 0.671, blue: 0.451),  // #6AAB73
        comment: Color(red: 0.478, green: 0.494, blue: 0.522), // #7A7E85
        number: Color(red: 0.165, green: 0.675, blue: 0.722),  // #2AACB8
        type: Color(red: 0.337, green: 0.659, blue: 0.961)     // #56A8F5
    )

    func color(for tokenType: TokenType) -> Color {
        switch tokenType {
        case .keyword: return keyword
        case .string, .jsonKey: return string
        case .comment: return comment
        case .number: return number
        case .type, .tagName, .attributeName, .propertyName: return type
        }
    }
}

// MARK: - Language Keywords

enum LanguageKeywords {
    static let swift: Set<String> = [
        "func", "var", "let", "class", "struct", "enum", "protocol", "import",
        "return", "if", "else", "for", "while", "guard", "switch", "case",
        "self", "true", "false", "nil", "async", "await", "actor", "some",
        "any", "public", "private", "internal", "init", "deinit", "throws",
        "throw", "try", "catch", "do", "in", "where", "typealias", "extension",
        "static", "override", "mutating", "final", "weak", "unowned", "lazy",
        "break", "continue", "default", "defer", "fallthrough", "repeat"
    ]

    static let python: Set<String> = [
        "def", "class", "import", "from", "return", "if", "elif", "else",
        "for", "while", "try", "except", "with", "as", "True", "False",
        "None", "self", "lambda", "yield", "async", "await", "pass",
        "raise", "finally", "del", "in", "not", "and", "or", "is",
        "global", "nonlocal", "assert", "break", "continue"
    ]

    static let javascript: Set<String> = [
        "function", "const", "let", "var", "class", "return", "if", "else",
        "for", "while", "import", "export", "from", "async", "await",
        "true", "false", "null", "undefined", "this", "new", "typeof",
        "interface", "type", "switch", "case", "break", "continue",
        "default", "do", "throw", "try", "catch", "finally", "in",
        "of", "instanceof", "yield", "delete", "void", "super", "extends"
    ]

    static let bash: Set<String> = [
        "if", "then", "else", "fi", "for", "do", "done", "while", "case",
        "esac", "echo", "export", "source", "function", "return", "local",
        "in", "select", "until", "shift", "break", "continue", "eval",
        "exec", "exit", "read", "set", "unset", "readonly", "declare"
    ]

    static let sql: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "CREATE",
        "TABLE", "JOIN", "ON", "AND", "OR", "NOT", "NULL", "INTO",
        "VALUES", "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "AS",
        "INNER", "LEFT", "RIGHT", "OUTER", "DISTINCT", "SET", "DROP",
        "ALTER", "INDEX", "VIEW", "UNION", "ALL", "EXISTS", "BETWEEN",
        "LIKE", "IN", "IS", "ASC", "DESC", "COUNT", "SUM", "AVG",
        "MIN", "MAX", "CASE", "WHEN", "THEN", "ELSE", "END",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "DEFAULT", "CONSTRAINT"
    ]

    static let kotlin: Set<String> = [
        "fun", "val", "var", "class", "object", "interface", "enum", "import",
        "return", "if", "else", "for", "while", "when", "is", "in",
        "true", "false", "null", "this", "super", "package", "override",
        "open", "abstract", "sealed", "data", "companion", "internal",
        "private", "protected", "public", "suspend", "lateinit", "lazy",
        "by", "init", "constructor", "throw", "try", "catch", "finally"
    ]

    static func keywords(for language: String) -> Set<String>? {
        switch language.lowercased() {
        case "swift": return swift
        case "python", "py": return python
        case "javascript", "js", "typescript", "ts", "jsx", "tsx": return javascript
        case "bash", "sh", "shell", "zsh": return bash
        case "sql": return sql
        case "kotlin", "kt": return kotlin
        default: return nil
        }
    }

    static func isCaseSensitive(for language: String) -> Bool {
        switch language.lowercased() {
        case "sql": return false
        default: return true
        }
    }
}

// MARK: - Tokenizer

enum Tokenizer {

    static func tokenize(_ code: String, language: String?) -> [Token] {
        let lang = language?.lowercased() ?? ""

        switch lang {
        case "json":
            return tokenizeJSON(code)
        case "html", "xml", "svg":
            return tokenizeHTML(code)
        case "css", "scss", "less":
            return tokenizeCSS(code)
        default:
            return tokenizeGeneric(code, language: language)
        }
    }

    // MARK: Generic Tokenizer

    private static func tokenizeGeneric(_ code: String, language: String?) -> [Token] {
        var tokens: [Token] = []
        let lang = language ?? ""
        let keywords = LanguageKeywords.keywords(for: lang)
        let caseSensitive = LanguageKeywords.isCaseSensitive(for: lang)
        let isPython = ["python", "py"].contains(lang.lowercased())
        let isBash = ["bash", "sh", "shell", "zsh"].contains(lang.lowercased())
        let hasHashComments = isPython || isBash

        let chars = Array(code.unicodeScalars)
        let count = chars.count
        var i = 0

        // Helper to get String.Index from scalar offset
        func stringIndex(at offset: Int) -> String.Index {
            code.unicodeScalars.index(code.startIndex, offsetBy: offset)
        }

        while i < count {
            let c = chars[i]

            // Line comments: // or #
            if c == "/" && i + 1 < count && chars[i + 1] == "/" {
                let start = i
                while i < count && chars[i] != "\n" { i += 1 }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .comment
                ))
                continue
            }

            if hasHashComments && c == "#" {
                let start = i
                while i < count && chars[i] != "\n" { i += 1 }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .comment
                ))
                continue
            }

            // Block comments: /* ... */
            if c == "/" && i + 1 < count && chars[i + 1] == "*" {
                let start = i
                i += 2
                while i + 1 < count {
                    if chars[i] == "*" && chars[i + 1] == "/" {
                        i += 2
                        break
                    }
                    i += 1
                }
                if i >= count { i = count }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .comment
                ))
                continue
            }

            // Strings: "..." or '...'
            if c == "\"" || c == "'" {
                let quote = c
                let start = i
                i += 1

                // Check for triple-quote (Python)
                if isPython && i + 1 < count && chars[i] == quote && chars[i + 1] == quote {
                    i += 2 // skip past the opening triple
                    while i + 2 < count {
                        if chars[i] == quote && chars[i + 1] == quote && chars[i + 2] == quote {
                            i += 3
                            break
                        }
                        i += 1
                    }
                    if i > count { i = count }
                } else {
                    while i < count && chars[i] != quote && chars[i] != "\n" {
                        if chars[i] == "\\" { i += 1 } // skip escaped char
                        i += 1
                    }
                    if i < count && chars[i] == quote { i += 1 }
                }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .string
                ))
                continue
            }

            // Backtick strings (JS template literals)
            if c == "`" {
                let start = i
                i += 1
                while i < count && chars[i] != "`" {
                    if chars[i] == "\\" { i += 1 }
                    i += 1
                }
                if i < count { i += 1 }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .string
                ))
                continue
            }

            // Numbers
            if c.properties.isASCIIHexDigit && (c >= "0" && c <= "9") {
                let start = i
                if c == "0" && i + 1 < count && (chars[i + 1] == "x" || chars[i + 1] == "X") {
                    i += 2
                    while i < count && chars[i].properties.isASCIIHexDigit { i += 1 }
                } else {
                    while i < count && ((chars[i] >= "0" && chars[i] <= "9") || chars[i] == "." || chars[i] == "_") { i += 1 }
                    if i < count && (chars[i] == "e" || chars[i] == "E") {
                        i += 1
                        if i < count && (chars[i] == "+" || chars[i] == "-") { i += 1 }
                        while i < count && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
                    }
                }
                // Make sure number isn't followed by identifier char
                if i >= count || !isIdentChar(chars[i]) {
                    tokens.append(Token(
                        range: stringIndex(at: start)..<stringIndex(at: i),
                        type: .number
                    ))
                    continue
                }
                // Otherwise it's part of an identifier, reset
                i = start
            }

            // Identifiers and keywords
            if isIdentStartChar(c) {
                let start = i
                while i < count && isIdentChar(chars[i]) { i += 1 }
                let word = String(code[stringIndex(at: start)..<stringIndex(at: i)])

                if let keywords {
                    let match = caseSensitive ? keywords.contains(word) : keywords.contains(word.uppercased())
                    if match {
                        tokens.append(Token(
                            range: stringIndex(at: start)..<stringIndex(at: i),
                            type: .keyword
                        ))
                        continue
                    }
                }

                // Type heuristic: starts with uppercase letter (Swift/Kotlin convention)
                if let first = word.first, first.isUppercase && first.isLetter && word.count > 1 {
                    tokens.append(Token(
                        range: stringIndex(at: start)..<stringIndex(at: i),
                        type: .type
                    ))
                    continue
                }

                // Not a keyword or type, skip
                continue
            }

            i += 1
        }

        return tokens
    }

    // MARK: JSON Tokenizer

    private static func tokenizeJSON(_ code: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(code.unicodeScalars)
        let count = chars.count
        var i = 0

        func stringIndex(at offset: Int) -> String.Index {
            code.unicodeScalars.index(code.startIndex, offsetBy: offset)
        }

        while i < count {
            let c = chars[i]

            // Strings
            if c == "\"" {
                let start = i
                i += 1
                while i < count && chars[i] != "\"" {
                    if chars[i] == "\\" { i += 1 }
                    i += 1
                }
                if i < count { i += 1 }
                let end = i

                // Check if this string is a key (followed by :)
                var j = end
                while j < count && (chars[j] == " " || chars[j] == "\t") { j += 1 }
                let isKey = j < count && chars[j] == ":"

                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: end),
                    type: isKey ? .keyword : .string
                ))
                continue
            }

            // Numbers
            if (c >= "0" && c <= "9") || (c == "-" && i + 1 < count && chars[i + 1] >= "0" && chars[i + 1] <= "9") {
                let start = i
                if c == "-" { i += 1 }
                while i < count && ((chars[i] >= "0" && chars[i] <= "9") || chars[i] == ".") { i += 1 }
                if i < count && (chars[i] == "e" || chars[i] == "E") {
                    i += 1
                    if i < count && (chars[i] == "+" || chars[i] == "-") { i += 1 }
                    while i < count && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
                }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .number
                ))
                continue
            }

            // Keywords: true, false, null
            if isIdentStartChar(c) {
                let start = i
                while i < count && isIdentChar(chars[i]) { i += 1 }
                let word = String(code[stringIndex(at: start)..<stringIndex(at: i)])
                if ["true", "false", "null"].contains(word) {
                    tokens.append(Token(
                        range: stringIndex(at: start)..<stringIndex(at: i),
                        type: .keyword
                    ))
                }
                continue
            }

            i += 1
        }

        return tokens
    }

    // MARK: HTML Tokenizer

    private static func tokenizeHTML(_ code: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(code.unicodeScalars)
        let count = chars.count
        var i = 0

        func stringIndex(at offset: Int) -> String.Index {
            code.unicodeScalars.index(code.startIndex, offsetBy: offset)
        }

        while i < count {
            let c = chars[i]

            // Comments: <!-- ... -->
            if c == "<" && i + 3 < count && chars[i + 1] == "!" && chars[i + 2] == "-" && chars[i + 3] == "-" {
                let start = i
                i += 4
                while i + 2 < count {
                    if chars[i] == "-" && chars[i + 1] == "-" && chars[i + 2] == ">" {
                        i += 3
                        break
                    }
                    i += 1
                }
                if i > count { i = count }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .comment
                ))
                continue
            }

            // Tags: <tagname or </tagname
            if c == "<" && i + 1 < count {
                var j = i + 1
                if j < count && chars[j] == "/" { j += 1 }
                if j < count && isIdentStartChar(chars[j]) {
                    let tagStart = j
                    while j < count && isIdentChar(chars[j]) { j += 1 }
                    tokens.append(Token(
                        range: stringIndex(at: tagStart)..<stringIndex(at: j),
                        type: .tagName
                    ))
                    i = j

                    // Scan for attributes inside the tag
                    while i < count && chars[i] != ">" {
                        // Attribute name
                        if isIdentStartChar(chars[i]) {
                            let attrStart = i
                            while i < count && (isIdentChar(chars[i]) || chars[i] == "-") { i += 1 }
                            tokens.append(Token(
                                range: stringIndex(at: attrStart)..<stringIndex(at: i),
                                type: .attributeName
                            ))
                            continue
                        }
                        // Strings in attributes
                        if chars[i] == "\"" || chars[i] == "'" {
                            let quote = chars[i]
                            let strStart = i
                            i += 1
                            while i < count && chars[i] != quote { i += 1 }
                            if i < count { i += 1 }
                            tokens.append(Token(
                                range: stringIndex(at: strStart)..<stringIndex(at: i),
                                type: .string
                            ))
                            continue
                        }
                        i += 1
                    }
                    continue
                }
            }

            // Strings outside tags
            if c == "\"" || c == "'" {
                let quote = c
                let start = i
                i += 1
                while i < count && chars[i] != quote { i += 1 }
                if i < count { i += 1 }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .string
                ))
                continue
            }

            i += 1
        }

        return tokens
    }

    // MARK: CSS Tokenizer

    private static func tokenizeCSS(_ code: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(code.unicodeScalars)
        let count = chars.count
        var i = 0

        func stringIndex(at offset: Int) -> String.Index {
            code.unicodeScalars.index(code.startIndex, offsetBy: offset)
        }

        while i < count {
            let c = chars[i]

            // Block comments
            if c == "/" && i + 1 < count && chars[i + 1] == "*" {
                let start = i
                i += 2
                while i + 1 < count {
                    if chars[i] == "*" && chars[i + 1] == "/" {
                        i += 2
                        break
                    }
                    i += 1
                }
                if i > count { i = count }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .comment
                ))
                continue
            }

            // Strings
            if c == "\"" || c == "'" {
                let quote = c
                let start = i
                i += 1
                while i < count && chars[i] != quote {
                    if chars[i] == "\\" { i += 1 }
                    i += 1
                }
                if i < count { i += 1 }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .string
                ))
                continue
            }

            // Property names (identifier followed by :)
            if isIdentStartChar(c) || c == "-" {
                let start = i
                while i < count && (isIdentChar(chars[i]) || chars[i] == "-") { i += 1 }
                var j = i
                while j < count && (chars[j] == " " || chars[j] == "\t") { j += 1 }
                if j < count && chars[j] == ":" {
                    tokens.append(Token(
                        range: stringIndex(at: start)..<stringIndex(at: i),
                        type: .propertyName
                    ))
                }
                continue
            }

            // Numbers with units
            if c >= "0" && c <= "9" {
                let start = i
                while i < count && ((chars[i] >= "0" && chars[i] <= "9") || chars[i] == ".") { i += 1 }
                // Include units like px, em, rem, %
                while i < count && isIdentChar(chars[i]) { i += 1 }
                tokens.append(Token(
                    range: stringIndex(at: start)..<stringIndex(at: i),
                    type: .number
                ))
                continue
            }

            i += 1
        }

        return tokens
    }

    // MARK: Character Helpers

    private static func isIdentStartChar(_ c: Unicode.Scalar) -> Bool {
        (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_" || c == "$" || c == "@"
    }

    private static func isIdentChar(_ c: Unicode.Scalar) -> Bool {
        isIdentStartChar(c) || (c >= "0" && c <= "9")
    }
}

// MARK: - Cache

@MainActor
final class HighlightCache {
    struct Key: Hashable {
        let code: String
        let language: String?
        let colorScheme: ColorScheme
    }

    private var cache: [Key: AttributedString] = [:]
    private var order: [Key] = []
    private let maxEntries = 50

    func get(key: Key) -> AttributedString? {
        cache[key]
    }

    func set(key: Key, value: AttributedString) {
        if cache[key] == nil {
            order.append(key)
        }
        cache[key] = value
        if order.count > maxEntries {
            let evicted = order.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }
}

// MARK: - CodeHighlighter

/// A lightweight, regex-based syntax highlighter for common programming languages.
///
/// `CodeHighlighter` tokenizes source code and applies foreground colors from a
/// light/dark color palette. Results are cached with an LRU strategy for performance.
///
/// Supported languages include Swift, Python, JavaScript/TypeScript, Bash, SQL,
/// Kotlin, JSON, HTML/XML, and CSS.
///
/// You typically do not call this type directly. Instead, use the
/// ``SwiftUICore/View/enableCodeHighlighting()`` view modifier which wires the
/// highlighter into the ``MarkdownView`` environment.
@MainActor
public struct CodeHighlighter {

    private static let cache = HighlightCache()

    /// Highlight source code and return an `AttributedString` with syntax colors.
    ///
    /// - Parameters:
    ///   - code: The raw source code to highlight.
    ///   - language: An optional language identifier (e.g., `"swift"`, `"python"`).
    ///     When `nil`, a generic tokenizer is used.
    ///   - colorScheme: The current color scheme, used to select light or dark palette.
    /// - Returns: An `AttributedString` with per-token foreground colors applied.
    public static func highlight(
        _ code: String,
        language: String?,
        colorScheme: ColorScheme
    ) -> AttributedString {
        let key = HighlightCache.Key(code: code, language: language, colorScheme: colorScheme)
        if let cached = cache.get(key: key) {
            return cached
        }

        let palette = colorScheme == .dark ? SyntaxColorPalette.dark : SyntaxColorPalette.light
        let tokens = Tokenizer.tokenize(code, language: language)

        var result = AttributedString(code)

        for token in tokens {
            guard let lower = AttributedString.Index(token.range.lowerBound, within: result),
                  let upper = AttributedString.Index(token.range.upperBound, within: result) else {
                continue
            }
            result[lower..<upper].foregroundColor = palette.color(for: token.type)
        }

        cache.set(key: key, value: result)
        return result
    }
}
