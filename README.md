# SecretMarkdown

Markdown rendering library with inline LaTeX support, optimized for AI chat interfaces with streaming output.

![Build & Test](https://github.com/nicktoozyakin/SecretMarkdown/actions/workflows/build-and-test.yml/badge.svg)

## Requirements

- Swift 6
- iOS 17+
- macOS 14+
- visionOS 1+

## Installation

Add SecretMarkdown as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nicktoozyakin/SecretMarkdown.git", from: "0.1.0"),
]
```

Then add the desired target to your module:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SecretMarkdownUI", package: "SecretMarkdown"),
    ]
)
```

### Available Products

| Product | Description |
|---|---|
| `SecretMarkdownParser` | Markdown to AST parser with LaTeX extraction |
| `SecretMarkdownUI` | SwiftUI renderer with theming and streaming |
| `SecretMarkdownHighlight` | Syntax highlighting (optional) |

## Diagnostics & observability

The package emits structured **diagnostic events** (parser anomalies, render
failures) and exposes **cumulative metrics** (parse duration, cache hit rates,
counters per diagnostic code). The host application chooses what to do with
them — the package never sends data anywhere on its own.

### Subscribe to diagnostics

```swift
import SecretMarkdownParser

final class TelemetrySink: MarkdownDiagnosticsObserver {
    func markdownDidEmitDiagnostic(_ d: MarkdownDiagnostic) {
        // d.severity / d.category / d.code / d.message / d.context
        // route to your analytics / crash reporter / log file
    }
}

let sink = TelemetrySink()
let subscription = MarkdownDiagnostics.shared.addObserver(sink)
// keep `subscription` alive for as long as you want events
```

The callback is delivered **asynchronously through a `Task`**. If your sink
touches `@MainActor`-isolated state, simply mark the conformance `@MainActor` —
the runtime dispatches each callback on the main actor automatically.

Tune behavior:

```swift
// Send only warnings and errors to observers (default: .debug — everything).
MarkdownDiagnostics.shared.minimumSeverity = .warning

// Mirror events to the unified logging system (Console.app).
// Default: true in DEBUG, false in RELEASE.
MarkdownDiagnostics.shared.mirrorsToOSLog = true

// Throttle high-frequency streaming.debug events: emit 1 of every N.
// Default: 100. Set to 1 to disable sampling.
MarkdownDiagnostics.shared.streamingDebugSamplingRate = 100

// Limit how much source text appears in diagnostic snippets.
// Default: 80 characters. Set to 0 to suppress snippets entirely.
MarkdownDiagnostics.shared.snippetMaxLength = 80
```

### Pull or subscribe to metrics

```swift
// Pull a snapshot at any time.
let metrics = MarkdownObservability.snapshot()
print(metrics.parseCount, metrics.latexCacheHitRate)

// Or subscribe for push updates.
final class Dashboard: MarkdownMetricsObserver {
    func markdownDidUpdateMetrics(_ m: MarkdownMetrics) {
        // refresh UI / record sample
    }
}
let metricsSubscription = MarkdownObservability.addObserver(Dashboard())
```

Performance traces are recorded with `OSSignposter` under subsystem
`com.secretmarkdown` (categories `parse`, `latex.render`, `streaming.reparse`,
`highlight`) — visible in Instruments without any host code. Toggle with
`MarkdownObservability.signpostsEnabled` (default: `true` in DEBUG,
`false` in RELEASE).

### Diagnostic codes

Each event carries a stable `MarkdownDiagnostic.Code`:

| Category | Codes |
|---|---|
| `parser` | `unknownBlockMarkup`, `unknownInlineMarkup`, `rawHTMLPreserved` |
| `latex` | `unclosedInlineLaTeX`, `unclosedDisplayLaTeX`, `unclosedBackslashParen`, `unclosedBackslashBracket`, `unclosedFencedCodeBlock`, `unclosedInlineCode`, `emptyLaTeXFormula`, `orphanLaTeXPlaceholder`, `displayPromotionSkipped` |
| `streaming` | `streamingUnclosedDelimiter` |
| `rendering` | `latexRenderFailed`, `latexFallbackActivated` |
| `highlighting` | `highlightTokenIndexFailed` |

### Privacy considerations

The diagnostic pipeline is designed to keep user content on-device by default,
but the **host is the final filter** for anything sent off-device:

- `MarkdownDiagnostic.Context.snippet` is truncated to
  `snippetMaxLength` characters (default 80). Set to `0` if any leakage of
  user input is unacceptable.
- The OSLog mirror writes the snippet with `.private(mask: .hash)` privacy
  qualifier — visible on-device for debugging, replaced with a stable hash
  in sysdiagnose / device archives.
- `Context.extra` only contains values placed there by the package itself
  (delimiter type, language, kind, token failure count). No user content.
- The package never sends events to the network. If you forward to a remote
  telemetry service, decide per-code whether to include `snippet` and how to
  scrub `message`.

### Resetting state for tests

```swift
MarkdownDiagnostics.shared.removeAllObservers()
MarkdownObservability.removeAllObservers()
MarkdownObservability.reset()
```

## License

See LICENSE for details.
