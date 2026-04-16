import Foundation

/// An incremental parser for streaming text, designed for AI chat responses.
///
/// `StreamingParser` buffers incoming text chunks and reparses on each update,
/// detecting unclosed delimiters (LaTeX `$`, fenced code blocks, etc.) so that
/// partially received content is rendered without visual glitches.
///
/// The parser is **thread-safe**: it uses `NSLock` internally and can be called
/// from any thread. It conforms to `Sendable` (unchecked, due to the lock-based
/// synchronization).
///
/// ## Usage
///
/// ```swift
/// let parser = StreamingParser()
/// // As chunks arrive from the network:
/// let doc1 = parser.append("Hello **wor")
/// let doc2 = parser.append("ld**")
/// // doc2.blocks now contains a paragraph with bold "world"
/// ```
public final class StreamingParser: @unchecked Sendable {

    private let lock = NSLock()
    private var _text: String = ""
    private var _document: ParsedDocument = ParsedDocument(blocks: [])
    private var _unclosedDelimiter: UnclosedDelimiter?

    /// Creates a new, empty streaming parser.
    public init() {}

    /// Append a chunk of text and return the updated parsed document.
    ///
    /// Call this method each time a new text fragment arrives (e.g., from an
    /// SSE stream). The parser appends the chunk to its internal buffer,
    /// reparses, and returns the full ``ParsedDocument``.
    ///
    /// - Parameter chunk: The new text fragment to append.
    /// - Returns: The full parsed document after incorporating the new chunk.
    @discardableResult
    public func append(_ chunk: String) -> ParsedDocument {
        lock.lock()
        defer { lock.unlock() }
        _text.append(chunk)
        return _reparse()
    }

    /// Replace the entire accumulated text and reparse from scratch.
    ///
    /// This is the preferred API when using SwiftUI bindings where the complete
    /// text is available on each update rather than incremental chunks.
    ///
    /// - Parameter fullText: The complete text to parse.
    /// - Returns: The full parsed document for the provided text.
    @discardableResult
    public func setText(_ fullText: String) -> ParsedDocument {
        lock.lock()
        defer { lock.unlock() }
        _text = fullText
        return _reparse()
    }

    /// The full text accumulated so far across all `append` and `setText` calls.
    public var currentText: String {
        lock.lock()
        defer { lock.unlock() }
        return _text
    }

    /// Whether the current text has unclosed delimiters (LaTeX `$`, fenced code blocks, etc.).
    ///
    /// When `true`, the parser is buffering trailing content that cannot yet be
    /// fully parsed. This is expected during active streaming.
    public var hasUnclosedDelimiters: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _unclosedDelimiter != nil
    }

    /// The most recently parsed document, without appending new text.
    public var currentDocument: ParsedDocument {
        lock.lock()
        defer { lock.unlock() }
        return _document
    }

    /// Reset the parser to its initial empty state, discarding all accumulated text.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _text = ""
        _document = ParsedDocument(blocks: [])
        _unclosedDelimiter = nil
    }

    // MARK: - Private

    /// Reparse the current text. Must be called while holding `lock`.
    private func _reparse() -> ParsedDocument {
        _unclosedDelimiter = DelimiterBuffer.findUnclosedDelimiter(in: _text)

        let textToParse: String
        if let unclosed = _unclosedDelimiter {
            // Parse only up to the unclosed delimiter; treat the rest as plain text
            let safePortion = String(_text[_text.startIndex..<unclosed.startIndex])
            let pendingPortion = String(_text[unclosed.startIndex...])

            if safePortion.isEmpty {
                // Everything is pending — just show as plain text
                let pendingBlock = BlockNode.paragraph(inlines: [.text(pendingPortion)])
                _document = ParsedDocument(blocks: [pendingBlock])
                return _document
            }

            // Parse the safe portion
            let parsed = SecretMarkdownParser.parse(safePortion)
            // Append pending text as a plain paragraph
            let pendingBlock = BlockNode.paragraph(inlines: [.text(pendingPortion)])
            _document = ParsedDocument(blocks: parsed.blocks + [pendingBlock])
            return _document
        } else {
            textToParse = _text
        }

        if textToParse.isEmpty {
            _document = ParsedDocument(blocks: [])
        } else {
            _document = SecretMarkdownParser.parse(textToParse)
        }
        return _document
    }
}
