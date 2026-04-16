import Foundation

/// A structured diagnostic event emitted by the SecretMarkdown parsing or rendering pipeline.
///
/// Hosts subscribe via ``MarkdownDiagnostics/addObserver(_:)`` to collect these events
/// for telemetry, debugging, or in-app display. The event carries enough structured
/// information (``Code``, ``Severity``, ``Category``) to be routed and aggregated
/// without parsing the human-readable ``message``.
///
/// > Privacy: ``Context/snippet`` may contain a fragment of the user's Markdown.
/// > It is sanitized to ``MarkdownDiagnostics/snippetMaxLength`` characters by default.
/// > Set the limit to `0` to suppress snippets entirely. The host is responsible for
/// > deciding what gets forwarded to external systems.
public struct MarkdownDiagnostic: Sendable, Identifiable {

    /// Unique identifier for this event instance.
    public let id: UUID

    /// Severity level. Compare against ``MarkdownDiagnostics/minimumSeverity``
    /// to decide whether to react.
    public let severity: Severity

    /// Subsystem that produced the event.
    public let category: Category

    /// Stable machine-readable identifier for the specific kind of issue.
    /// Use this (not ``message``) for routing, deduplication, and aggregation.
    public let code: Code

    /// Human-readable description. May change between versions — do not parse.
    public let message: String

    /// Additional context (sanitized snippet, source location, extra fields).
    public let context: Context

    /// When the event was created.
    public let timestamp: Date

    /// Create a diagnostic event.
    ///
    /// Hosts typically receive events from the broadcaster rather than constructing them,
    /// but the initializer is public to allow re-emission from custom layers
    /// (e.g., a host-side wrapper that adds correlation IDs).
    public init(
        id: UUID = UUID(),
        severity: Severity,
        category: Category,
        code: Code,
        message: String,
        context: Context = .empty,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.severity = severity
        self.category = category
        self.code = code
        self.message = message
        self.context = context
        self.timestamp = timestamp
    }

    // MARK: - Severity

    /// Severity of a ``MarkdownDiagnostic``. Ordered from least to most serious.
    public enum Severity: Int, Sendable, Comparable, CaseIterable {
        /// High-frequency tracing events (e.g., streaming buffer states).
        /// Heavily sampled by default — see ``MarkdownDiagnostics/streamingDebugSamplingRate``.
        case debug = 0
        /// Informational events that may be useful for understanding behavior
        /// (e.g., raw HTML preserved as-is for security review).
        case info = 1
        /// Notable but non-problematic conditions.
        case notice = 2
        /// Recoverable issues — output is produced but may not match the user's intent
        /// (e.g., unclosed LaTeX delimiter rendered as literal text).
        case warning = 3
        /// Internal invariant violations or unrecoverable rendering failures.
        case error = 4

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Category

    /// The subsystem that produced a diagnostic.
    public enum Category: String, Sendable, CaseIterable {
        /// Top-level Markdown parsing (block/inline conversion, unknown markup).
        case parser
        /// LaTeX extraction and placeholder replacement.
        case latex
        /// Incremental streaming parser.
        case streaming
        /// View-layer rendering (LaTeX images, fallback paths).
        case rendering
        /// Code block syntax highlighting.
        case highlighting
    }

    // MARK: - Code

    /// Stable, machine-readable identifier for a specific diagnostic kind.
    ///
    /// Codes form a closed enumeration so hosts can `switch` on them without
    /// a `default` branch. Adding a new code is a source-breaking change for
    /// exhaustive switches by design — it forces hosts to consider new conditions.
    public enum Code: String, Sendable, CaseIterable {

        // MARK: parser

        /// A Markdown construct from swift-markdown was not recognized and was dropped.
        case unknownBlockMarkup
        /// An inline Markdown construct was not recognized and was dropped.
        case unknownInlineMarkup
        /// Raw HTML was preserved verbatim. Hosts may want to sanitize before display.
        case rawHTMLPreserved

        // MARK: latex extraction / replacement

        /// `$...$` opened but never closed; treated as literal text.
        case unclosedInlineLaTeX
        /// `$$...$$` opened but never closed; treated as literal text.
        case unclosedDisplayLaTeX
        /// `\(...\)` opened but never closed; treated as literal text.
        case unclosedBackslashParen
        /// `\[...\]` opened but never closed; treated as literal text.
        case unclosedBackslashBracket
        /// A fenced code block (``` or ~~~) opened but never closed;
        /// the rest of the input was consumed as code.
        case unclosedFencedCodeBlock
        /// An inline code span opened with backticks was never closed;
        /// treated as literal backticks.
        case unclosedInlineCode
        /// A LaTeX delimiter pair contained empty content (e.g., `$$`).
        case emptyLaTeXFormula
        /// **Invariant violation:** a placeholder UUID was found in the AST without
        /// a corresponding entry in the extraction mapping. Indicates a bug.
        case orphanLaTeXPlaceholder
        /// Could not promote a single-formula paragraph to a display block because
        /// the entry was not found. Visual layout may differ from intent.
        case displayPromotionSkipped

        // MARK: streaming

        /// The streaming parser detected an unclosed delimiter while buffering.
        /// Expected during active streaming — sampled by default.
        case streamingUnclosedDelimiter

        // MARK: rendering (UI target)

        /// SwiftMath could not produce an image for the LaTeX formula.
        case latexRenderFailed
        /// View-layer fallback (rendering as code-style text) was activated.
        case latexFallbackActivated

        // MARK: highlighting

        /// A token range could not be mapped to an `AttributedString.Index`.
        /// The token is shown unhighlighted.
        case highlightTokenIndexFailed
    }

    // MARK: - Context

    /// Optional structured context attached to a diagnostic.
    public struct Context: Sendable {

        /// A sanitized fragment of the source text related to the event.
        /// Length-limited per ``MarkdownDiagnostics/snippetMaxLength``.
        /// `nil` if snippets are disabled or no fragment applies.
        public let snippet: String?

        /// Position in the source text (Unicode scalar offset), if applicable.
        public let location: Int?

        /// Additional public fields safe for telemetry (no user content).
        /// Examples: `"language": "swift"`, `"size": "1024"`.
        public let extra: [String: String]

        public init(
            snippet: String? = nil,
            location: Int? = nil,
            extra: [String: String] = [:]
        ) {
            self.snippet = snippet
            self.location = location
            self.extra = extra
        }

        /// An empty context with no fields populated.
        public static let empty = Context()
    }
}
