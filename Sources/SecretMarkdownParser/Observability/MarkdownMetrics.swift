import Foundation

/// A snapshot of cumulative metrics from the SecretMarkdown pipeline.
///
/// Hosts pull a snapshot via ``MarkdownObservability/snapshot()`` or subscribe
/// to push updates via ``MarkdownObservability/addObserver(_:)``. Counts are
/// cumulative since the last ``MarkdownObservability/reset()``.
public struct MarkdownMetrics: Sendable {

    /// Total number of completed top-level `parse` calls.
    public let parseCount: Int

    /// Sum of wall-clock duration of all completed parses, in seconds.
    public let totalParseDuration: TimeInterval

    /// Total number of LaTeX formulas (inline + display) extracted across all parses.
    public let latexFormulasExtracted: Int

    /// Total number of LaTeX render calls (cache hits + misses).
    public let latexRenderCount: Int

    /// Number of LaTeX render calls that returned `nil` (SwiftMath could not produce an image).
    public let latexRenderFailures: Int

    /// LaTeX image cache hits.
    public let latexCacheHits: Int

    /// LaTeX image cache misses.
    public let latexCacheMisses: Int

    /// Code-highlighting cache hits.
    public let highlightCacheHits: Int

    /// Code-highlighting cache misses.
    public let highlightCacheMisses: Int

    /// Number of incremental reparses performed by ``StreamingParser``.
    public let streamingReparseCount: Int

    /// Cumulative count of diagnostics, broken down by ``MarkdownDiagnostic/Code``.
    public let diagnosticsByCode: [MarkdownDiagnostic.Code: Int]

    /// Cumulative count of diagnostics, broken down by ``MarkdownDiagnostic/Severity``.
    public let diagnosticsBySeverity: [MarkdownDiagnostic.Severity: Int]

    /// Average parse duration. Returns `0` when ``parseCount`` is zero.
    public var averageParseDuration: TimeInterval {
        guard parseCount > 0 else { return 0 }
        return totalParseDuration / Double(parseCount)
    }

    /// LaTeX cache hit rate in `[0, 1]`. Returns `0` when no cache lookups have occurred.
    public var latexCacheHitRate: Double {
        let total = latexCacheHits + latexCacheMisses
        guard total > 0 else { return 0 }
        return Double(latexCacheHits) / Double(total)
    }

    /// Code-highlighting cache hit rate in `[0, 1]`.
    public var highlightCacheHitRate: Double {
        let total = highlightCacheHits + highlightCacheMisses
        guard total > 0 else { return 0 }
        return Double(highlightCacheHits) / Double(total)
    }

    public init(
        parseCount: Int,
        totalParseDuration: TimeInterval,
        latexFormulasExtracted: Int,
        latexRenderCount: Int,
        latexRenderFailures: Int,
        latexCacheHits: Int,
        latexCacheMisses: Int,
        highlightCacheHits: Int,
        highlightCacheMisses: Int,
        streamingReparseCount: Int,
        diagnosticsByCode: [MarkdownDiagnostic.Code: Int],
        diagnosticsBySeverity: [MarkdownDiagnostic.Severity: Int]
    ) {
        self.parseCount = parseCount
        self.totalParseDuration = totalParseDuration
        self.latexFormulasExtracted = latexFormulasExtracted
        self.latexRenderCount = latexRenderCount
        self.latexRenderFailures = latexRenderFailures
        self.latexCacheHits = latexCacheHits
        self.latexCacheMisses = latexCacheMisses
        self.highlightCacheHits = highlightCacheHits
        self.highlightCacheMisses = highlightCacheMisses
        self.streamingReparseCount = streamingReparseCount
        self.diagnosticsByCode = diagnosticsByCode
        self.diagnosticsBySeverity = diagnosticsBySeverity
    }

    /// All-zero metrics. Useful for tests and as a baseline.
    public static let empty = MarkdownMetrics(
        parseCount: 0,
        totalParseDuration: 0,
        latexFormulasExtracted: 0,
        latexRenderCount: 0,
        latexRenderFailures: 0,
        latexCacheHits: 0,
        latexCacheMisses: 0,
        highlightCacheHits: 0,
        highlightCacheMisses: 0,
        streamingReparseCount: 0,
        diagnosticsByCode: [:],
        diagnosticsBySeverity: [:]
    )
}
