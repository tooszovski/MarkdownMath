import Foundation
import os

/// Observer for cumulative metrics updates.
///
/// Implementations are notified after every event that mutates metrics — typically
/// after each completed parse, LaTeX render, cache lookup, or diagnostic emission.
///
/// > Important: The callback may be invoked from any thread. Implementations must
/// > be thread-safe and fast (no I/O on the calling thread).
///
/// > Warning: Do not call back into the SecretMarkdown pipeline (parsing, rendering)
/// > from this callback. Doing so may trigger further metric updates and lead to
/// > unbounded recursion.
public protocol MarkdownMetricsObserver: AnyObject, Sendable {
    /// Called when metrics have changed. Always receives a fresh snapshot.
    func markdownDidUpdateMetrics(_ metrics: MarkdownMetrics)
}

/// Token returned by ``MarkdownObservability/addObserver(_:)``.
///
/// Cancels automatically on deallocation; ``cancel()`` is idempotent.
public final class MarkdownMetricsSubscription: @unchecked Sendable {
    private let onCancel: @Sendable () -> Void
    private let didCancel = OSAllocatedUnfairLock<Bool>(initialState: false)

    init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    deinit {
        cancel()
    }

    /// Stop receiving metric updates.
    public func cancel() {
        let shouldCancel: Bool = didCancel.withLock { already in
            if already { return false }
            already = true
            return true
        }
        if shouldCancel {
            onCancel()
        }
    }
}

/// Centralized metrics and Apple signposts for the SecretMarkdown pipeline.
///
/// Hosts can:
///
/// - Pull the current snapshot with ``snapshot()``.
/// - Subscribe to push updates with ``addObserver(_:)``.
/// - Toggle ``signpostsEnabled`` to record `OSSignposter` intervals (visible in Instruments).
/// - Reset all counters with ``reset()``.
///
/// All operations are thread-safe.
public enum MarkdownObservability {

    // MARK: - State

    /// Note: configuration fields (`signpostsEnabled`) live alongside cumulative
    /// counters but are intentionally **not** cleared by `reset()`.
    private struct State {
        var parseCount = 0
        var totalParseDuration: TimeInterval = 0
        var latexFormulasExtracted = 0
        var latexRenderCount = 0
        var latexRenderFailures = 0
        var latexCacheHits = 0
        var latexCacheMisses = 0
        var highlightCacheHits = 0
        var highlightCacheMisses = 0
        var streamingReparseCount = 0
        var diagnosticsByCode: [MarkdownDiagnostic.Code: Int] = [:]
        var diagnosticsBySeverity: [MarkdownDiagnostic.Severity: Int] = [:]
        var signpostsEnabled: Bool = MarkdownObservability.defaultSignpostsEnabled
        var observers: [ObjectIdentifier: WeakMetricsBox] = [:]
    }

    private static let lock = OSAllocatedUnfairLock<State>(initialState: State())

    private static var defaultSignpostsEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Public API

    /// Capture a snapshot of current metrics.
    public static func snapshot() -> MarkdownMetrics {
        lock.withLock { state in
            buildMetrics(from: state)
        }
    }

    /// Subscribe to push updates whenever metrics change.
    @discardableResult
    public static func addObserver(_ observer: MarkdownMetricsObserver) -> MarkdownMetricsSubscription {
        let key = ObjectIdentifier(observer)
        lock.withLock { state in
            state.observers[key] = WeakMetricsBox(observer)
        }
        return MarkdownMetricsSubscription {
            lock.withLock { state in
                state.observers[key] = nil
            }
        }
    }

    /// Remove all metric observers. Primarily for test teardown.
    public static func removeAllObservers() {
        lock.withLock { $0.observers.removeAll() }
    }

    /// Whether `OSSignposter` intervals are recorded.
    ///
    /// Default: `true` in DEBUG, `false` in RELEASE. Recording signposts has minimal
    /// overhead when no Instruments tool is attached, so leaving this on in DEBUG
    /// is generally fine.
    public static var signpostsEnabled: Bool {
        get { lock.withLock { $0.signpostsEnabled } }
        set { lock.withLock { $0.signpostsEnabled = newValue } }
    }

    /// Reset all cumulative counters to zero. Does not affect observers or
    /// configuration (`signpostsEnabled`).
    public static func reset() {
        let payload = mutateAndMaybeSnapshot { state in
            state.parseCount = 0
            state.totalParseDuration = 0
            state.latexFormulasExtracted = 0
            state.latexRenderCount = 0
            state.latexRenderFailures = 0
            state.latexCacheHits = 0
            state.latexCacheMisses = 0
            state.highlightCacheHits = 0
            state.highlightCacheMisses = 0
            state.streamingReparseCount = 0
            state.diagnosticsByCode = [:]
            state.diagnosticsBySeverity = [:]
        }
        guard let (metrics, observers) = payload else { return }
        notify(metrics: metrics, to: observers)
    }

    // MARK: - SPI: counters

    @_spi(Internal)
    public static func recordParse(duration: TimeInterval, formulasExtracted: Int) {
        let payload = mutateAndMaybeSnapshot { state in
            state.parseCount += 1
            state.totalParseDuration += duration
            state.latexFormulasExtracted += formulasExtracted
        }
        guard let (metrics, observers) = payload else { return }
        notify(metrics: metrics, to: observers)
    }

    @_spi(Internal)
    public static func recordLatexRender(failed: Bool) {
        let payload = mutateAndMaybeSnapshot { state in
            state.latexRenderCount += 1
            if failed { state.latexRenderFailures += 1 }
        }
        guard let (metrics, observers) = payload else { return }
        notify(metrics: metrics, to: observers)
    }

    @_spi(Internal)
    public static func recordLatexCache(hit: Bool) {
        let payload = mutateAndMaybeSnapshot { state in
            if hit { state.latexCacheHits += 1 }
            else { state.latexCacheMisses += 1 }
        }
        guard let (metrics, observers) = payload else { return }
        notify(metrics: metrics, to: observers)
    }

    @_spi(Internal)
    public static func recordHighlightCache(hit: Bool) {
        let payload = mutateAndMaybeSnapshot { state in
            if hit { state.highlightCacheHits += 1 }
            else { state.highlightCacheMisses += 1 }
        }
        guard let (metrics, observers) = payload else { return }
        notify(metrics: metrics, to: observers)
    }

    @_spi(Internal)
    public static func recordStreamingReparse() {
        let payload = mutateAndMaybeSnapshot { state in
            state.streamingReparseCount += 1
        }
        guard let (metrics, observers) = payload else { return }
        notify(metrics: metrics, to: observers)
    }

    @_spi(Internal)
    public static func recordDiagnostic(
        severity: MarkdownDiagnostic.Severity,
        code: MarkdownDiagnostic.Code
    ) {
        let payload = mutateAndMaybeSnapshot { state in
            state.diagnosticsByCode[code, default: 0] += 1
            state.diagnosticsBySeverity[severity, default: 0] += 1
        }
        guard let (metrics, observers) = payload else { return }
        notify(metrics: metrics, to: observers)
    }

    // MARK: - Internal helpers

    /// Mutate state and, only when at least one observer is registered, snapshot
    /// observers and build the metrics struct.
    ///
    /// Returns `nil` when there are no observers — the hot path then short-circuits
    /// without allocating `MarkdownMetrics` (two Dictionary copies). Counter mutation
    /// still happens, so subsequent `snapshot()` pulls reflect the new value.
    private static func mutateAndMaybeSnapshot(
        _ mutation: @Sendable (inout State) -> Void
    ) -> (MarkdownMetrics, [MarkdownMetricsObserver])? {
        lock.withLock { state in
            mutation(&state)
            guard !state.observers.isEmpty else { return nil }
            let observers = state.observers.values.compactMap { $0.observer }
            guard !observers.isEmpty else { return nil }
            let metrics = buildMetrics(from: state)
            return (metrics, observers)
        }
    }

    private static func buildMetrics(from state: State) -> MarkdownMetrics {
        MarkdownMetrics(
            parseCount: state.parseCount,
            totalParseDuration: state.totalParseDuration,
            latexFormulasExtracted: state.latexFormulasExtracted,
            latexRenderCount: state.latexRenderCount,
            latexRenderFailures: state.latexRenderFailures,
            latexCacheHits: state.latexCacheHits,
            latexCacheMisses: state.latexCacheMisses,
            highlightCacheHits: state.highlightCacheHits,
            highlightCacheMisses: state.highlightCacheMisses,
            streamingReparseCount: state.streamingReparseCount,
            diagnosticsByCode: state.diagnosticsByCode,
            diagnosticsBySeverity: state.diagnosticsBySeverity
        )
    }

    private static func notify(
        metrics: MarkdownMetrics,
        to observers: [MarkdownMetricsObserver]
    ) {
        guard !observers.isEmpty else { return }
        for observer in observers {
            observer.markdownDidUpdateMetrics(metrics)
        }
    }
}

// MARK: - Internal weak box

/// Weak wrapper. `@unchecked Sendable` is safe here because Swift's weak storage
/// is thread-safe at the runtime level and the wrapped reference is a `Sendable`
/// `AnyObject`-bound protocol.
private struct WeakMetricsBox: @unchecked Sendable {
    weak var observer: MarkdownMetricsObserver?

    init(_ observer: MarkdownMetricsObserver) {
        self.observer = observer
    }
}
