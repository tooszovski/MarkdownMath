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

    /// Result of `_reparseUnlocked` — carries the data needed for observability
    /// emission outside the parser's lock.
    private struct ReparseOutcome {
        let document: ParsedDocument
        let unclosedDelimiter: UnclosedDelimiter?
        let textSnapshot: String
    }

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
        let outcome = withLock {
            _text.append(chunk)
            return _reparseUnlocked()
        }
        emitObservability(for: outcome)
        return outcome.document
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
        let outcome = withLock {
            _text = fullText
            return _reparseUnlocked()
        }
        emitObservability(for: outcome)
        return outcome.document
    }

    /// The full text accumulated so far across all `append` and `setText` calls.
    public var currentText: String {
        withLock { _text }
    }

    /// Whether the current text has unclosed delimiters (LaTeX `$`, fenced code blocks, etc.).
    ///
    /// When `true`, the parser is buffering trailing content that cannot yet be
    /// fully parsed. This is expected during active streaming.
    public var hasUnclosedDelimiters: Bool {
        withLock { _unclosedDelimiter != nil }
    }

    /// The most recently parsed document, without appending new text.
    public var currentDocument: ParsedDocument {
        withLock { _document }
    }

    /// Reset the parser to its initial empty state, discarding all accumulated text.
    public func reset() {
        withLock {
            _text = ""
            _document = ParsedDocument(blocks: [])
            _unclosedDelimiter = nil
        }
    }

    // MARK: - Private

    /// Helper that wraps `lock.lock() / defer unlock` around a closure. Keeps
    /// observability emission strictly outside the lock window — calling
    /// `MarkdownDiagnostics`/`MarkdownObservability` while `lock` is held risks
    /// host-side re-entrancy because `NSLock` is non-recursive.
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Reparse the current text. Caller must hold `lock`.
    /// Performs **no** observability emission — that is the public method's
    /// responsibility, after the lock is released.
    private func _reparseUnlocked() -> ReparseOutcome {
        _unclosedDelimiter = DelimiterBuffer.findUnclosedDelimiter(in: _text)

        if let unclosed = _unclosedDelimiter {
            // Parse only up to the unclosed delimiter; treat the rest as plain text
            let safePortion = String(_text[_text.startIndex..<unclosed.startIndex])
            let pendingPortion = String(_text[unclosed.startIndex...])

            if safePortion.isEmpty {
                let pendingBlock = BlockNode.paragraph(inlines: [.text(pendingPortion)])
                _document = ParsedDocument(blocks: [pendingBlock])
            } else {
                let parsed = MarkdownMathParser.parse(safePortion)
                let pendingBlock = BlockNode.paragraph(inlines: [.text(pendingPortion)])
                _document = ParsedDocument(blocks: parsed.blocks + [pendingBlock])
            }
        } else if _text.isEmpty {
            _document = ParsedDocument(blocks: [])
        } else {
            _document = MarkdownMathParser.parse(_text)
        }

        return ReparseOutcome(
            document: _document,
            unclosedDelimiter: _unclosedDelimiter,
            textSnapshot: _text
        )
    }

    /// Emit metrics + sampled diagnostic for a reparse. Called outside the lock.
    private func emitObservability(for outcome: ReparseOutcome) {
        MarkdownObservability.recordStreamingReparse()
        guard let unclosed = outcome.unclosedDelimiter else { return }
        let diagnostics = MarkdownDiagnostics.shared
        guard diagnostics.shouldEmitStreamingDebug() else { return }
        let scalars = outcome.textSnapshot.unicodeScalars
        let scalarOffset = scalars.distance(
            from: scalars.startIndex,
            to: unclosed.startIndex.samePosition(in: scalars) ?? scalars.startIndex
        )
        diagnostics.emit(
            severity: .debug,
            category: .streaming,
            code: .streamingUnclosedDelimiter,
            message: "Streaming buffer holds unclosed delimiter; pending content rendered as plain text.",
            context: MarkdownDiagnostic.Context(
                snippet: nil,
                location: scalarOffset,
                extra: ["delimiter": String(describing: unclosed.type)]
            )
        )
    }
}
