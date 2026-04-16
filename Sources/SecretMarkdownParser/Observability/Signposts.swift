import Foundation
import os

/// Apple signposts for performance tracing in Instruments.
///
/// Wraps `OSSignposter` with a check against ``MarkdownObservability/signpostsEnabled``
/// so the cost of recording is paid only when enabled.
enum Signposts {

    static let subsystem = "com.secretmarkdown"

    static let parser = OSSignposter(subsystem: subsystem, category: "parse")
    static let latex = OSSignposter(subsystem: subsystem, category: "latex.render")
    static let streaming = OSSignposter(subsystem: subsystem, category: "streaming.reparse")
    static let highlight = OSSignposter(subsystem: subsystem, category: "highlight")

    /// Run `work` inside a signpost interval if signposts are enabled.
    ///
    /// The interval is named `name` and shows up in Instruments' Points of Interest
    /// or custom `os_signpost` tracks. When signposts are disabled, `work` runs
    /// directly with no overhead.
    @inline(__always)
    static func interval<T>(
        _ signposter: OSSignposter,
        _ name: StaticString,
        _ work: () throws -> T
    ) rethrows -> T {
        // Intentionally racy: a stale read of the signpost gate is acceptable —
        // the worst case is one extra/missed signpost, never a correctness issue.
        guard MarkdownObservability.signpostsEnabled else {
            return try work()
        }
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try work()
    }

    /// Emit a single point-in-time event if signposts are enabled.
    @inline(__always)
    static func event(
        _ signposter: OSSignposter,
        _ name: StaticString
    ) {
        // Intentionally racy: see `interval` for rationale.
        guard MarkdownObservability.signpostsEnabled else { return }
        signposter.emitEvent(name)
    }
}
