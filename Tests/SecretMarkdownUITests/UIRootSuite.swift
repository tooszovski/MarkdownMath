import Testing
import Foundation
@_spi(Internal) @testable import SecretMarkdownParser
@testable import SecretMarkdownUI
import SwiftMath

// MARK: - Test stream observer

private final class UIDiagnosticStream: MarkdownDiagnosticsObserver, @unchecked Sendable {
    private let continuation: AsyncStream<MarkdownDiagnostic>.Continuation
    let stream: AsyncStream<MarkdownDiagnostic>

    init() {
        var captured: AsyncStream<MarkdownDiagnostic>.Continuation!
        self.stream = AsyncStream(bufferingPolicy: .unbounded) { c in captured = c }
        self.continuation = captured
    }

    func markdownDidEmitDiagnostic(_ diagnostic: MarkdownDiagnostic) {
        continuation.yield(diagnostic)
    }

    func finish() { continuation.finish() }
}

private enum UITestError: Error { case timeout }

private extension AsyncStream where Element == MarkdownDiagnostic {
    func firstEvent(
        matching predicate: @escaping @Sendable (MarkdownDiagnostic) -> Bool,
        timeout: Duration = .seconds(2)
    ) async throws -> MarkdownDiagnostic {
        try await withThrowingTaskGroup(of: MarkdownDiagnostic.self) { group in
            group.addTask {
                for await event in self {
                    if predicate(event) { return event }
                }
                throw UITestError.timeout
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw UITestError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

private func resetUIDiagnostics() {
    let d = MarkdownDiagnostics.shared
    d.removeAllObservers()
    d.minimumSeverity = .debug
    d.snippetMaxLength = 80
    d.mirrorsToOSLog = false
    MarkdownObservability.removeAllObservers()
    MarkdownObservability.reset()
    MarkdownObservability.signpostsEnabled = false
}

// MARK: - Root suite

/// Single `.serialized` root for all SecretMarkdownUI tests so the global
/// `MarkdownDiagnostics.shared` and `MarkdownObservability` state cannot be
/// raced across nested suites. UI tests share state with the LaTeX cache and
/// the global diagnostics broadcaster, so isolation must be process-wide
/// within this target.
@Suite("SecretMarkdownUI", .serialized)
struct UIRootSuite {

    @Suite("LaTeXRenderer (no diagnostics interaction)")
    struct LaTeXRendererTests {

        @Test("renders simple formula to non-nil image")
        @MainActor
        func renderSimpleFormula() {
            let image = LaTeXRenderer.render("x^2")
            #expect(image != nil, "Expected a non-nil image for valid LaTeX")
        }

        @Test("returns nil for invalid LaTeX")
        @MainActor
        func renderInvalidLaTeX() {
            let image = LaTeXRenderer.render("{")
            #expect(image == nil, "Expected nil for invalid LaTeX")
        }
    }

    @Suite("UI diagnostics & observability")
    struct DiagnosticsTests {

        init() { resetUIDiagnostics() }

        @Test("invalid LaTeX emits latexRenderFailed (error)")
        @MainActor
        func renderFailureEmits() async throws {
            let observer = UIDiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)
            defer { sub.cancel(); observer.finish() }

            _ = LaTeXRenderer.render("{")

            let event = try await observer.stream.firstEvent { $0.code == .latexRenderFailed }
            #expect(event.severity == .error)
            #expect(event.category == .rendering)
        }

        @Test("successful render does not emit a render-failure diagnostic")
        @MainActor
        func successfulRenderEmitsNoFailure() async throws {
            let observer = UIDiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)

            _ = LaTeXRenderer.render("x^2")

            // Allow async observer Task to drain, then close stream BEFORE
            // iterating — `for await` would otherwise block forever waiting
            // on a `finish()` that only runs in defer after the loop exits.
            try await Task.sleep(for: .milliseconds(80))
            sub.cancel()
            observer.finish()

            var seen: [MarkdownDiagnostic] = []
            for await event in observer.stream {
                seen.append(event)
            }
            #expect(!seen.contains { $0.code == .latexRenderFailed })
        }

        @Test("LaTeXCache miss then hit are reflected in observability metrics")
        @MainActor
        func cacheHitMissMetrics() {
            let cache = LaTeXCache(maxSize: 4)
            let textColor = MTColor.black

            _ = cache.get(latex: "x", fontSize: 16, isDarkMode: false, displayStyle: false)
            if let image = LaTeXRenderer.render("x", fontSize: 16, textColor: textColor) {
                cache.set(image, latex: "x", fontSize: 16, isDarkMode: false, displayStyle: false)
            }
            _ = cache.get(latex: "x", fontSize: 16, isDarkMode: false, displayStyle: false)

            let snap = MarkdownObservability.snapshot()
            #expect(snap.latexCacheMisses >= 1)
            #expect(snap.latexCacheHits >= 1)
            #expect(snap.latexRenderCount >= 1)
        }

        @Test("failed render bumps latexRenderFailures counter and diagnostics counter")
        @MainActor
        func renderFailureCounter() {
            _ = LaTeXRenderer.render("{")
            let snap = MarkdownObservability.snapshot()
            #expect(snap.latexRenderFailures >= 1)
            #expect((snap.diagnosticsByCode[.latexRenderFailed] ?? 0) >= 1)
        }
    }
}
