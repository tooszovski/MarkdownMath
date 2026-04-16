import Foundation
import os

/// Receives diagnostic events from the SecretMarkdown pipeline.
///
/// Implement this protocol on a class owned by your host application,
/// register it with ``MarkdownDiagnostics/addObserver(_:)``, and forward
/// events to your telemetry pipeline.
///
/// > Important: The callback is delivered **synchronously on the calling thread**
/// > (typically wherever your code invoked parsing or rendering). It may arrive
/// > on the main thread, on `Task.detached` background threads, or on any other
/// > queue depending on how the host app drives the pipeline.
/// >
/// > The conformer is responsible for actor isolation. If your observer touches
/// > `@MainActor`-isolated state, dispatch the work yourself:
/// >
/// > ```swift
/// > final class MyObserver: MarkdownDiagnosticsObserver {
/// >     func markdownDidEmitDiagnostic(_ d: MarkdownDiagnostic) {
/// >         Task { @MainActor in
/// >             // ...mutate UI state safely...
/// >         }
/// >     }
/// > }
/// > ```
///
/// > Warning: Do not call back into the SecretMarkdown pipeline (parsing, rendering)
/// > from this callback. Doing so may trigger further diagnostic emissions and lead
/// > to unbounded recursion.
public protocol MarkdownDiagnosticsObserver: AnyObject, Sendable {
    /// Called when a new diagnostic event is emitted that passes the configured
    /// ``MarkdownDiagnostics/minimumSeverity`` threshold.
    func markdownDidEmitDiagnostic(_ diagnostic: MarkdownDiagnostic)
}

/// Token returned by ``MarkdownDiagnostics/addObserver(_:)``.
///
/// The subscription is automatically cancelled when this object is deallocated.
/// You may also call ``cancel()`` explicitly.
public final class MarkdownDiagnosticsSubscription: @unchecked Sendable {
    private let onCancel: @Sendable () -> Void
    private let didCancel = OSAllocatedUnfairLock<Bool>(initialState: false)

    init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    deinit {
        cancel()
    }

    /// Stop receiving diagnostics. Idempotent — subsequent calls are no-ops.
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

/// Broadcast diagnostic events from the SecretMarkdown pipeline to host observers.
///
/// ## Overview
///
/// `MarkdownDiagnostics.shared` is the single broadcaster used by all three targets
/// (`SecretMarkdownParser`, `SecretMarkdownUI`, `SecretMarkdownHighlight`).
/// Hosts subscribe with ``addObserver(_:)`` and tune behavior with
/// ``minimumSeverity``, ``mirrorsToOSLog``, ``streamingDebugSamplingRate``,
/// and ``snippetMaxLength``.
///
/// ## Thread safety
///
/// All public properties and methods are thread-safe.
///
/// ## Performance
///
/// When `observers` is empty, ``mirrorsToOSLog`` is `false`, and severity is
/// below the threshold, emission is short-circuited before any allocation.
public final class MarkdownDiagnostics: @unchecked Sendable {

    /// The shared broadcaster used by all SecretMarkdown targets.
    public static let shared = MarkdownDiagnostics()

    // MARK: - Internal state

    private struct State {
        var observers: [ObjectIdentifier: WeakObserverBox] = [:]
        var minimumSeverity: MarkdownDiagnostic.Severity = .debug
        var mirrorsToOSLog: Bool = MarkdownDiagnostics.defaultMirrorsToOSLog
        var streamingDebugSamplingRate: Int = 100
        var snippetMaxLength: Int = 80
        var streamingDebugCounter: Int = 0
    }

    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    private static var defaultMirrorsToOSLog: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Create an isolated broadcaster.
    ///
    /// Most code should use ``shared``. A custom instance is useful for unit tests
    /// where you need full isolation from the global broadcaster.
    public init() {}

    // MARK: - Configuration

    /// Minimum severity that observers will receive. Events below this level are
    /// short-circuited before allocation.
    ///
    /// Default: ``MarkdownDiagnostic/Severity/debug`` (everything).
    public var minimumSeverity: MarkdownDiagnostic.Severity {
        get { lock.withLock { $0.minimumSeverity } }
        set { lock.withLock { $0.minimumSeverity = newValue } }
    }

    /// Whether events are also written to the unified logging system (`os.Logger`).
    ///
    /// Default: `true` in DEBUG builds, `false` in RELEASE. Hosts may override at
    /// runtime — useful when temporarily enabling diagnostics in production.
    public var mirrorsToOSLog: Bool {
        get { lock.withLock { $0.mirrorsToOSLog } }
        set { lock.withLock { $0.mirrorsToOSLog = newValue } }
    }

    /// Sampling rate for ``MarkdownDiagnostic/Code/streamingUnclosedDelimiter`` debug events.
    ///
    /// A value of `N` emits 1 of every `N` events. Default: `100`.
    /// Set to `1` to disable sampling (emit every event).
    public var streamingDebugSamplingRate: Int {
        get { lock.withLock { $0.streamingDebugSamplingRate } }
        set { lock.withLock { $0.streamingDebugSamplingRate = max(1, newValue) } }
    }

    /// Maximum number of characters of source text included in
    /// ``MarkdownDiagnostic/Context/snippet``.
    ///
    /// Default: `80`. Set to `0` to suppress snippets entirely (useful when
    /// any leakage of user content is unacceptable).
    public var snippetMaxLength: Int {
        get { lock.withLock { $0.snippetMaxLength } }
        set { lock.withLock { $0.snippetMaxLength = max(0, newValue) } }
    }

    // MARK: - Subscriptions

    /// Subscribe to diagnostic events.
    ///
    /// The observer is held weakly. The returned subscription cancels automatically
    /// when deallocated; retain it for as long as you want to receive events.
    @discardableResult
    public func addObserver(_ observer: MarkdownDiagnosticsObserver) -> MarkdownDiagnosticsSubscription {
        let key = ObjectIdentifier(observer)
        lock.withLock { state in
            state.observers[key] = WeakObserverBox(observer)
        }
        return MarkdownDiagnosticsSubscription { [weak self] in
            self?.lock.withLock { state in
                state.observers[key] = nil
            }
        }
    }

    /// Remove all observers. Primarily useful for test teardown.
    public func removeAllObservers() {
        lock.withLock { $0.observers.removeAll() }
    }

    // MARK: - SPI: emission

    /// Emit a diagnostic event. SPI for use by SecretMarkdown targets only.
    ///
    /// `message` and `context` are autoclosures so they are not evaluated when
    /// the event is filtered out by ``minimumSeverity``.
    @_spi(Internal)
    public func emit(
        severity: MarkdownDiagnostic.Severity,
        category: MarkdownDiagnostic.Category,
        code: MarkdownDiagnostic.Code,
        message: @autoclosure () -> String,
        context: @autoclosure () -> MarkdownDiagnostic.Context = .empty
    ) {
        // Cheap gate first: read only the severity threshold, no allocation.
        // Filtered events still bump counters so a later `snapshot()` is honest.
        let minSeverity = lock.withLock { $0.minimumSeverity }
        guard severity >= minSeverity else {
            MarkdownObservability.recordDiagnostic(severity: severity, code: code)
            return
        }

        // Full snapshot for actual emission.
        let snapshot = lock.withLock { state -> EmissionSnapshot in
            EmissionSnapshot(
                minimumSeverity: minSeverity,
                mirrorsToOSLog: state.mirrorsToOSLog,
                observers: state.observers.values.compactMap { $0.observer }
            )
        }

        if !(snapshot.observers.isEmpty && !snapshot.mirrorsToOSLog) {
            let event = MarkdownDiagnostic(
                severity: severity,
                category: category,
                code: code,
                message: message(),
                context: context()
            )

            if snapshot.mirrorsToOSLog {
                OSLogBridge.log(event)
            }

            for observer in snapshot.observers {
                observer.markdownDidEmitDiagnostic(event)
            }
        }

        // Metrics updated last so that a host implementing both
        // `MarkdownDiagnosticsObserver` and `MarkdownMetricsObserver` sees the
        // diagnostic event before it sees the counter that reflects it.
        MarkdownObservability.recordDiagnostic(severity: severity, code: code)
    }

    /// Sampling gate for streaming `.debug` events. Returns `true` once every
    /// ``streamingDebugSamplingRate`` calls. SPI for SecretMarkdown targets.
    @_spi(Internal)
    public func shouldEmitStreamingDebug() -> Bool {
        lock.withLock { state in
            state.streamingDebugCounter += 1
            if state.streamingDebugCounter >= state.streamingDebugSamplingRate {
                state.streamingDebugCounter = 0
                return true
            }
            return false
        }
    }

    /// Truncate `source` to ``snippetMaxLength`` characters, returning `nil` when
    /// snippets are disabled. SPI for SecretMarkdown targets.
    @_spi(Internal)
    public func sanitizedSnippet(_ source: String) -> String? {
        let maxLen = snippetMaxLength
        guard maxLen > 0 else { return nil }
        if source.count <= maxLen {
            return source
        }
        return String(source.prefix(maxLen)) + "…"
    }
}

// MARK: - Internal helpers

/// Weak wrapper. `@unchecked Sendable` is safe here because Swift's weak storage
/// is thread-safe at the runtime level and the wrapped reference is a `Sendable`
/// `AnyObject`-bound protocol.
private struct WeakObserverBox: @unchecked Sendable {
    weak var observer: MarkdownDiagnosticsObserver?

    init(_ observer: MarkdownDiagnosticsObserver) {
        self.observer = observer
    }
}

private struct EmissionSnapshot {
    let minimumSeverity: MarkdownDiagnostic.Severity
    let mirrorsToOSLog: Bool
    let observers: [MarkdownDiagnosticsObserver]
}
