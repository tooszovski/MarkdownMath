import Foundation
import os

/// Bridges ``MarkdownDiagnostic`` events to Apple's unified logging system.
enum OSLogBridge {

    static let subsystem = "com.secretmarkdown"

    /// Logger per category. Cached because the underlying handle is created lazily
    /// and we want a stable category identifier in Console.app / `log stream`.
    private static let loggers: [MarkdownDiagnostic.Category: Logger] = {
        var map: [MarkdownDiagnostic.Category: Logger] = [:]
        for category in MarkdownDiagnostic.Category.allCases {
            map[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
        return map
    }()

    /// Forward a diagnostic to the matching `Logger`.
    ///
    /// Privacy:
    /// - Code, severity, category are public (safe technical identifiers).
    /// - Message is public (we control the text — never includes raw user content).
    /// - Snippet is `.private(mask: .hash)` — visible on-device for debugging,
    ///   replaced with a stable hash in sysdiagnose / device archives.
    /// - Extra fields are public (callers must only put non-PII keys/values here).
    static func log(_ diagnostic: MarkdownDiagnostic) {
        let logger = loggers[diagnostic.category]
            ?? Logger(subsystem: subsystem, category: "default")

        let code = diagnostic.code.rawValue
        let message = diagnostic.message
        let snippet = diagnostic.context.snippet ?? ""

        switch diagnostic.severity {
        case .debug:
            logger.debug("[\(code, privacy: .public)] \(message, privacy: .public) snippet=\(snippet, privacy: .private(mask: .hash))")
        case .info:
            logger.info("[\(code, privacy: .public)] \(message, privacy: .public) snippet=\(snippet, privacy: .private(mask: .hash))")
        case .notice:
            logger.notice("[\(code, privacy: .public)] \(message, privacy: .public) snippet=\(snippet, privacy: .private(mask: .hash))")
        case .warning:
            logger.warning("[\(code, privacy: .public)] \(message, privacy: .public) snippet=\(snippet, privacy: .private(mask: .hash))")
        case .error:
            logger.error("[\(code, privacy: .public)] \(message, privacy: .public) snippet=\(snippet, privacy: .private(mask: .hash))")
        }
    }
}
