import Foundation
@_spi(Internal) @testable import MarkdownMathParser

// MARK: - Errors

enum DiagnosticTestError: Error {
    case timeout
    case streamEnded
}

// MARK: - Diagnostics observer that exposes events as an AsyncStream

final class DiagnosticStream: MarkdownDiagnosticsObserver, @unchecked Sendable {
    private let continuation: AsyncStream<MarkdownDiagnostic>.Continuation
    let stream: AsyncStream<MarkdownDiagnostic>

    init() {
        var captured: AsyncStream<MarkdownDiagnostic>.Continuation!
        self.stream = AsyncStream(bufferingPolicy: .unbounded) { c in
            captured = c
        }
        self.continuation = captured
    }

    func markdownDidEmitDiagnostic(_ diagnostic: MarkdownDiagnostic) {
        continuation.yield(diagnostic)
    }

    func finish() {
        continuation.finish()
    }
}

// MARK: - Metrics observer that exposes snapshots as an AsyncStream

final class MetricsStream: MarkdownMetricsObserver, @unchecked Sendable {
    private let continuation: AsyncStream<MarkdownMetrics>.Continuation
    let stream: AsyncStream<MarkdownMetrics>

    init() {
        var captured: AsyncStream<MarkdownMetrics>.Continuation!
        self.stream = AsyncStream(bufferingPolicy: .unbounded) { c in
            captured = c
        }
        self.continuation = captured
    }

    func markdownDidUpdateMetrics(_ metrics: MarkdownMetrics) {
        continuation.yield(metrics)
    }

    func finish() {
        continuation.finish()
    }
}

// MARK: - Stream helpers

extension AsyncStream where Element == MarkdownDiagnostic {

    /// Wait for the first event matching `predicate` or throw on timeout.
    func firstEvent(
        matching predicate: @escaping @Sendable (MarkdownDiagnostic) -> Bool,
        timeout: Duration = .seconds(2)
    ) async throws -> MarkdownDiagnostic {
        try await withThrowingTaskGroup(of: MarkdownDiagnostic.self) { group in
            group.addTask {
                for await event in self {
                    if predicate(event) { return event }
                }
                throw DiagnosticTestError.streamEnded
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw DiagnosticTestError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Collect events that arrive within `delay`.
    func collect(within delay: Duration = .milliseconds(150)) async -> [MarkdownDiagnostic] {
        try? await Task.sleep(for: delay)
        var events: [MarkdownDiagnostic] = []
        for await event in self {
            events.append(event)
            if events.count > 1000 { break } // safety net
        }
        return events
    }
}

extension AsyncStream where Element == MarkdownMetrics {

    /// Wait for the first metrics snapshot satisfying `predicate` or throw on timeout.
    func firstMetrics(
        where predicate: @escaping @Sendable (MarkdownMetrics) -> Bool,
        timeout: Duration = .seconds(2)
    ) async throws -> MarkdownMetrics {
        try await withThrowingTaskGroup(of: MarkdownMetrics.self) { group in
            group.addTask {
                for await metrics in self {
                    if predicate(metrics) { return metrics }
                }
                throw DiagnosticTestError.streamEnded
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw DiagnosticTestError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Test isolation

/// Reset all global diagnostic / observability state to defaults.
/// Call from `init()` of a `.serialized` `@Suite`.
func resetDiagnosticsForTest() {
    let diagnostics = MarkdownDiagnostics.shared
    diagnostics.removeAllObservers()
    diagnostics.minimumSeverity = .debug
    diagnostics.streamingDebugSamplingRate = 100
    diagnostics.snippetMaxLength = 80
    diagnostics.mirrorsToOSLog = false  // keep test output clean
    MarkdownObservability.removeAllObservers()
    MarkdownObservability.reset()
    MarkdownObservability.signpostsEnabled = false
}
