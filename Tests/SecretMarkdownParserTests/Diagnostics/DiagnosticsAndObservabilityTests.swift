import Testing
import Foundation
@_spi(Internal) @testable import SecretMarkdownParser

/// Root suite for all diagnostics + observability tests. Marked `.serialized`
/// so the global `MarkdownDiagnostics.shared` and `MarkdownObservability` state
/// is not raced across nested suites.
@Suite("Diagnostics & Observability", .serialized)
struct DiagnosticsRootSuite {

    // MARK: - Infrastructure: lifecycle, threshold, sampler, snippet

    @Suite("MarkdownDiagnostics infrastructure")
    struct InfrastructureTests {

        init() { resetDiagnosticsForTest() }

        // MARK: Subscription lifecycle

        @Test("addObserver receives subsequent events")
        func observerReceivesEvents() async throws {
            let observer = DiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)
            defer { sub.cancel(); observer.finish() }

            _ = SecretMarkdownParser.parse("$$ unclosed")

            let event = try await observer.stream.firstEvent {
                $0.code == .unclosedDisplayLaTeX
            }
            #expect(event.severity == .warning)
            #expect(event.category == .latex)
        }

        @Test("cancelled subscription stops delivery")
        func cancelledSubscription() async throws {
            let observer = DiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)
            sub.cancel()
            observer.finish()

            _ = SecretMarkdownParser.parse("$$ unclosed")

            var seen: [MarkdownDiagnostic] = []
            for await event in observer.stream {
                seen.append(event)
            }
            #expect(seen.isEmpty)
        }

        @Test("subscription auto-cancels on deinit")
        func subscriptionAutoCancel() async throws {
            let observer = DiagnosticStream()
            do {
                _ = MarkdownDiagnostics.shared.addObserver(observer)
            }
            observer.finish()

            _ = SecretMarkdownParser.parse("$$ unclosed")

            var seen: [MarkdownDiagnostic] = []
            for await event in observer.stream {
                seen.append(event)
            }
            #expect(seen.isEmpty)
        }

        @Test("multiple observers all receive the same event")
        func multipleObservers() async throws {
            let a = DiagnosticStream()
            let b = DiagnosticStream()
            let subA = MarkdownDiagnostics.shared.addObserver(a)
            let subB = MarkdownDiagnostics.shared.addObserver(b)
            defer { subA.cancel(); subB.cancel(); a.finish(); b.finish() }

            _ = SecretMarkdownParser.parse("$$ unclosed")

            let eventA = try await a.stream.firstEvent { $0.code == .unclosedDisplayLaTeX }
            let eventB = try await b.stream.firstEvent { $0.code == .unclosedDisplayLaTeX }
            #expect(eventA.code == eventB.code)
        }

        // MARK: Severity threshold

        @Test("events below minimumSeverity are filtered")
        func severityThresholdFilters() async throws {
            MarkdownDiagnostics.shared.minimumSeverity = .warning

            let observer = DiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)
            defer { sub.cancel(); observer.finish() }

            _ = SecretMarkdownParser.parse("$$ unclosed display")

            let warning = try await observer.stream.firstEvent {
                $0.code == .unclosedDisplayLaTeX
            }
            #expect(warning.severity == .warning)
        }

        @Test("severity ordering is debug < info < notice < warning < error")
        func severityOrdering() {
            let order: [MarkdownDiagnostic.Severity] = [.debug, .info, .notice, .warning, .error]
            for i in 0..<(order.count - 1) {
                #expect(order[i] < order[i + 1])
            }
        }

        @Test("filtered events still increment counters for snapshot()")
        func filteredCountersBump() async throws {
            MarkdownDiagnostics.shared.minimumSeverity = .error
            _ = SecretMarkdownParser.parse("$$ unclosed")
            // recordDiagnostic runs synchronously inside emit's filtered path,
            // so the counter is visible immediately on the calling thread.
            let snap = MarkdownObservability.snapshot()
            #expect((snap.diagnosticsByCode[.unclosedDisplayLaTeX] ?? 0) >= 1)
        }

        // MARK: Snippet sanitization

        @Test("sanitizedSnippet truncates with ellipsis when too long")
        func snippetTruncation() {
            MarkdownDiagnostics.shared.snippetMaxLength = 10
            let result = MarkdownDiagnostics.shared.sanitizedSnippet("0123456789ABCDEF")
            #expect(result == "0123456789…")
        }

        @Test("sanitizedSnippet returns nil when length is zero")
        func snippetDisabled() {
            MarkdownDiagnostics.shared.snippetMaxLength = 0
            #expect(MarkdownDiagnostics.shared.sanitizedSnippet("anything") == nil)
        }

        // MARK: Streaming sampler

        @Test("shouldEmitStreamingDebug fires once per N calls")
        func streamingSamplerRate() {
            MarkdownDiagnostics.shared.streamingDebugSamplingRate = 5
            var fires = 0
            for _ in 0..<25 {
                if MarkdownDiagnostics.shared.shouldEmitStreamingDebug() {
                    fires += 1
                }
            }
            #expect(fires == 5)
        }

        @Test("sampling rate clamps to >= 1")
        func streamingSamplerClamp() {
            MarkdownDiagnostics.shared.streamingDebugSamplingRate = 0
            #expect(MarkdownDiagnostics.shared.streamingDebugSamplingRate == 1)
            let firesEveryCall = (0..<3).map { _ in
                MarkdownDiagnostics.shared.shouldEmitStreamingDebug()
            }
            #expect(firesEveryCall.allSatisfy { $0 })
        }
    }

    // MARK: - Emission per code

    @Suite("Diagnostic emission per code")
    struct EmissionTests {

        init() { resetDiagnosticsForTest() }

        private func eventCode(
            triggeredBy markdown: String,
            expecting code: MarkdownDiagnostic.Code,
            timeout: Duration = .seconds(2)
        ) async throws -> MarkdownDiagnostic {
            let observer = DiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)
            defer { sub.cancel(); observer.finish() }
            _ = SecretMarkdownParser.parse(markdown)
            return try await observer.stream.firstEvent(matching: { $0.code == code }, timeout: timeout)
        }

        @Test("unclosed $$ emits unclosedDisplayLaTeX (warning)")
        func unclosedDisplayLaTeX() async throws {
            let event = try await eventCode(triggeredBy: "leading text\n\n$$ x = 1",
                                            expecting: .unclosedDisplayLaTeX)
            #expect(event.severity == .warning)
            #expect(event.category == .latex)
        }

        @Test("unclosed \\[ emits unclosedBackslashBracket (warning)")
        func unclosedBackslashBracket() async throws {
            let event = try await eventCode(triggeredBy: "foo \\[ x = 1",
                                            expecting: .unclosedBackslashBracket)
            #expect(event.severity == .warning)
        }

        @Test("unclosed \\( emits unclosedBackslashParen (warning)")
        func unclosedBackslashParen() async throws {
            let event = try await eventCode(triggeredBy: "foo \\( x = 1",
                                            expecting: .unclosedBackslashParen)
            #expect(event.severity == .warning)
        }

        @Test("unclosed $ emits unclosedInlineLaTeX (warning)")
        func unclosedInlineLaTeX() async throws {
            let event = try await eventCode(triggeredBy: "foo $ x =",
                                            expecting: .unclosedInlineLaTeX)
            #expect(event.severity == .warning)
        }

        @Test("unclosed fenced block emits unclosedFencedCodeBlock (warning)")
        func unclosedFencedCodeBlock() async throws {
            let event = try await eventCode(
                triggeredBy: "```swift\nlet x = 1\n",
                expecting: .unclosedFencedCodeBlock
            )
            #expect(event.severity == .warning)
            #expect(event.category == .latex)
        }

        @Test("unclosed inline code emits unclosedInlineCode (debug)")
        func unclosedInlineCode() async throws {
            let event = try await eventCode(triggeredBy: "text `unterminated trailing words",
                                            expecting: .unclosedInlineCode)
            #expect(event.severity == .debug)
        }

        @Test("empty $$$$ emits emptyLaTeXFormula (debug)")
        func emptyLaTeXFormula() async throws {
            let event = try await eventCode(triggeredBy: "para $$$$ trail",
                                            expecting: .emptyLaTeXFormula)
            #expect(event.severity == .debug)
        }

        @Test("HTML block emits rawHTMLPreserved (info)")
        func rawHTMLPreservedBlock() async throws {
            let event = try await eventCode(
                triggeredBy: "<div>raw block</div>\n\nparagraph",
                expecting: .rawHTMLPreserved
            )
            #expect(event.severity == .info)
            #expect(event.category == .parser)
            #expect(event.context.extra["kind"] == "block")
        }

        @Test("inline HTML emits rawHTMLPreserved with kind=inline")
        func rawHTMLPreservedInline() async throws {
            let observer = DiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)
            defer { sub.cancel(); observer.finish() }
            _ = SecretMarkdownParser.parse("text with <span>inline</span> html")
            let inline = try await observer.stream.firstEvent {
                $0.code == .rawHTMLPreserved && $0.context.extra["kind"] == "inline"
            }
            #expect(inline.severity == .info)
        }

        @Test("streaming unclosed delimiter emits debug event when sampled")
        func streamingUnclosedDelimiter() async throws {
            MarkdownDiagnostics.shared.streamingDebugSamplingRate = 1

            let observer = DiagnosticStream()
            let sub = MarkdownDiagnostics.shared.addObserver(observer)
            defer { sub.cancel(); observer.finish() }

            let parser = StreamingParser()
            _ = parser.append("partial $")

            let event = try await observer.stream.firstEvent {
                $0.code == .streamingUnclosedDelimiter
            }
            #expect(event.severity == .debug)
            #expect(event.category == .streaming)
            #expect(event.context.extra["delimiter"] != nil)
        }

        @Test("warning event includes sanitized snippet and location")
        func contextHasSnippetAndLocation() async throws {
            let event = try await eventCode(triggeredBy: "leading\n\n$$ broken trail",
                                            expecting: .unclosedDisplayLaTeX)
            #expect(event.context.snippet != nil)
            #expect(event.context.location != nil)
            if let loc = event.context.location { #expect(loc >= 0) }
        }

        @Test("snippet is omitted when snippetMaxLength is zero")
        func snippetSuppressed() async throws {
            MarkdownDiagnostics.shared.snippetMaxLength = 0
            let event = try await eventCode(triggeredBy: "$$ broken",
                                            expecting: .unclosedDisplayLaTeX)
            #expect(event.context.snippet == nil)
        }
    }

    // MARK: - Observability (push + pull, metrics)

    @Suite("MarkdownObservability")
    struct ObservabilityTests {

        init() { resetDiagnosticsForTest() }

        @Test("snapshot starts empty after reset")
        func emptyAfterReset() {
            let snap = MarkdownObservability.snapshot()
            #expect(snap.parseCount == 0)
            #expect(snap.totalParseDuration == 0)
            #expect(snap.diagnosticsByCode.isEmpty)
            #expect(snap.diagnosticsBySeverity.isEmpty)
            #expect(snap.latexCacheHitRate == 0)
            #expect(snap.highlightCacheHitRate == 0)
        }

        @Test("parse increments parseCount and totalParseDuration")
        func parseIncrements() {
            _ = SecretMarkdownParser.parse("# hello")
            _ = SecretMarkdownParser.parse("# world")
            let snap = MarkdownObservability.snapshot()
            #expect(snap.parseCount == 2)
            #expect(snap.totalParseDuration >= 0)
            #expect(snap.averageParseDuration >= 0)
        }

        @Test("parse with LaTeX bumps latexFormulasExtracted")
        func latexCounter() {
            _ = SecretMarkdownParser.parse("$x$ and $y$ and $$z$$")
            let snap = MarkdownObservability.snapshot()
            #expect(snap.latexFormulasExtracted == 3)
        }

        @Test("metrics observer receives an update after parse")
        func observerReceivesUpdate() async throws {
            let observer = MetricsStream()
            let sub = MarkdownObservability.addObserver(observer)
            defer { sub.cancel(); observer.finish() }

            _ = SecretMarkdownParser.parse("# hello")

            let metrics = try await observer.stream.firstMetrics { $0.parseCount >= 1 }
            #expect(metrics.parseCount >= 1)
        }

        @Test("cancelled metrics subscription stops delivery")
        func cancelledMetricsSubscription() async {
            let observer = MetricsStream()
            let sub = MarkdownObservability.addObserver(observer)
            sub.cancel()
            observer.finish()

            _ = SecretMarkdownParser.parse("# hi")

            var seen: [MarkdownMetrics] = []
            for await metrics in observer.stream {
                seen.append(metrics)
            }
            #expect(seen.isEmpty)
        }

        @Test("snapshot reflects the same counters that observer received")
        func pullPushConsistency() async throws {
            let observer = MetricsStream()
            let sub = MarkdownObservability.addObserver(observer)
            defer { sub.cancel(); observer.finish() }

            _ = SecretMarkdownParser.parse("# header\n\n$$ unclosed")

            let pushed = try await observer.stream.firstMetrics { $0.parseCount >= 1 }
            let pulled = MarkdownObservability.snapshot()
            #expect(pulled.parseCount >= pushed.parseCount)
        }

        @Test("reset clears counters but preserves observer registration")
        func resetClearsCounters() async throws {
            let observer = MetricsStream()
            let sub = MarkdownObservability.addObserver(observer)
            defer { sub.cancel(); observer.finish() }

            _ = SecretMarkdownParser.parse("# hi")
            _ = try await observer.stream.firstMetrics { $0.parseCount >= 1 }

            MarkdownObservability.reset()
            let cleared = try await observer.stream.firstMetrics { $0.parseCount == 0 }
            #expect(cleared.parseCount == 0)
            #expect(cleared.totalParseDuration == 0)
        }

        @Test("cacheHitRate reflects hits/misses")
        func cacheHitRateMath() {
            let metrics = MarkdownMetrics(
                parseCount: 1,
                totalParseDuration: 0.1,
                latexFormulasExtracted: 0,
                latexRenderCount: 0,
                latexRenderFailures: 0,
                latexCacheHits: 7,
                latexCacheMisses: 3,
                highlightCacheHits: 0,
                highlightCacheMisses: 0,
                streamingReparseCount: 0,
                diagnosticsByCode: [:],
                diagnosticsBySeverity: [:]
            )
            #expect(metrics.latexCacheHitRate == 0.7)
        }

        @Test("hit rate is zero when no lookups occurred")
        func cacheHitRateZeroWhenEmpty() {
            let snap = MarkdownObservability.snapshot()
            #expect(snap.latexCacheHitRate == 0)
            #expect(snap.highlightCacheHitRate == 0)
        }
    }
}
