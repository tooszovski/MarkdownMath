# MarkdownMath

Native SwiftUI rendering of Markdown with inline and display LaTeX, built for AI chat interfaces where text arrives token by token.

![Build & Test](https://github.com/tooszovski/MarkdownMath/actions/workflows/build-and-test.yml/badge.svg)

## Features

- **CommonMark + GFM** via Apple's [swift-markdown](https://github.com/swiftlang/swift-markdown): headings, emphasis, links, lists, block quotes, code blocks, tables, thematic breaks.
- **LaTeX** inline (`$...$`, `\(...\)`) and display (`$$...$$`, `\[...\]`), rendered natively with [SwiftMath](https://github.com/mgriebling/SwiftMath). Rendered formulas are cached, and each formula gets an accessibility label.
- **Streaming mode** for incremental output: unclosed LaTeX delimiters (`$`, `$$`, `\(`, `\[`), inline code and fenced code blocks are buffered, so a half-received message renders without flicker or broken markup.
- **Theming** through the SwiftUI environment, with `default` and `compact` presets.
- **Optional syntax highlighting** for Swift, Python, JavaScript, TypeScript, Bash, SQL, Kotlin, JSON, HTML and CSS.
- **Diagnostics and metrics** you can route to your own logging or crash reporter. The package never sends anything off-device.
- Swift 6 language mode, strict concurrency.

## Requirements

- Swift 6.0+ / Xcode 16+
- iOS 17+, macOS 14+, visionOS 1+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tooszovski/MarkdownMath.git", from: "0.1.0"),
]
```

Then add the products you need:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "MarkdownMathUI", package: "MarkdownMath"),
        .product(name: "MarkdownMathHighlight", package: "MarkdownMath"),
    ]
)
```

In Xcode: **File → Add Package Dependencies…** and paste the repository URL.

### Products

| Product | Description |
|---|---|
| `MarkdownMathParser` | Markdown to AST parser with LaTeX extraction and a streaming parser. No UI dependencies |
| `MarkdownMathUI` | SwiftUI renderer: `MarkdownView`, themes, LaTeX views |
| `MarkdownMathHighlight` | Optional syntax highlighting for code blocks |

## Usage

### Static text

```swift
import MarkdownMathUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            MarkdownView("""
            # Hello **World**

            Einstein's formula: $E = mc^2$

            $$\\int_0^1 x^2\\,dx = \\frac{1}{3}$$
            """)
            .padding()
        }
    }
}
```

### Streaming (AI chat)

Pass the accumulated text and a flag while the response is still arriving:

```swift
struct ChatBubble: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        MarkdownView(text: text, isStreaming: isStreaming)
            .markdownTheme(.compact)
    }
}
```

When `isStreaming` becomes `false`, the final text is parsed once more without buffering.

If you need the AST outside SwiftUI, use the parser directly:

```swift
import MarkdownMathParser

let parser = StreamingParser()
for try await chunk in tokens {
    let document = parser.append(chunk)
    // render `document` or inspect `parser.hasUnclosedDelimiters`
}
```

`MarkdownView(document:)` renders a pre-parsed `ParsedDocument`.

### Theming

Adjust fonts, colors and spacing through the environment:

```swift
MarkdownView(content)
    .markdownTheme { theme in
        theme.bodyFont = .callout
        theme.linkColor = .accentColor
        theme.codeBlockBackgroundColor = .gray.opacity(0.1)
        theme.paragraphSpacing = 8
    }
```

Or use a preset: `.markdownTheme(.default)` / `.markdownTheme(.compact)`.

### Code highlighting

```swift
import MarkdownMathHighlight

MarkdownView(content)
    .enableCodeHighlighting()
```

## Example app

`Example/` contains a demo app with static, streaming and theming screens. Open `Example/Package.swift` in Xcode and run the `MarkdownMathDemo` scheme.

## Testing

```bash
swift test
```

## Diagnostics & observability

The package emits structured **diagnostic events** (parser anomalies, render
failures) and exposes **cumulative metrics** (parse duration, cache hit rates,
counters per diagnostic code). The host application chooses what to do with
them — the package never sends data anywhere on its own.

### Subscribe to diagnostics

```swift
import MarkdownMathParser

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
`com.markdownmath` (categories `parse`, `latex.render`, `streaming.reparse`,
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

MarkdownMath is released under the MIT License. See [LICENSE](LICENSE) for details.

LaTeX rendering is built on [SwiftMath](https://github.com/mgriebling/SwiftMath) (MIT), Markdown parsing on [swift-markdown](https://github.com/swiftlang/swift-markdown) (Apache 2.0).

