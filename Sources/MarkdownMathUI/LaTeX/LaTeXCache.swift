import SwiftUI
import SwiftMath
@_spi(Internal) import MarkdownMathParser

#if canImport(UIKit)
import UIKit
#endif

/// An LRU (least-recently-used) cache for rendered LaTeX images.
///
/// Images are keyed by the LaTeX string, font size, display style, and color scheme.
/// When the cache exceeds ``init(maxSize:)``, the least recently accessed entry is evicted.
///
/// On iOS, the cache automatically clears itself on memory warnings.
///
/// Access the shared singleton via ``shared``, or create a custom instance for testing.
@MainActor
public final class LaTeXCache {

    /// The shared singleton cache instance used by ``LaTeXRenderer``.
    public static let shared = LaTeXCache()

    // MARK: - Cache Key

    private struct CacheKey: Hashable {
        let latex: String
        let fontSize: CGFloat
        let isDarkMode: Bool
        let displayStyle: Bool
    }

    // MARK: - Storage

    private var cache: [CacheKey: MTImage] = [:]
    private var accessOrder: [CacheKey] = []
    private let maxSize: Int

    // MARK: - Init

    /// Creates a new LaTeX image cache.
    ///
    /// - Parameter maxSize: The maximum number of images to keep in the cache.
    ///   Defaults to 100.
    public init(maxSize: Int = 100) {
        self.maxSize = maxSize
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clear()
            }
        }
        #endif
    }

    // MARK: - Public API

    /// Retrieve a cached image for the given parameters, or `nil` if not cached.
    ///
    /// Accessing an entry moves it to the most-recently-used position.
    ///
    /// - Parameters:
    ///   - latex: The LaTeX formula string.
    ///   - fontSize: The font size used for rendering.
    ///   - isDarkMode: Whether the image was rendered for dark mode.
    ///   - displayStyle: Whether display (block) mode was used.
    /// - Returns: The cached image, or `nil` if no match was found.
    public func get(
        latex: String,
        fontSize: CGFloat,
        isDarkMode: Bool,
        displayStyle: Bool
    ) -> MTImage? {
        let key = CacheKey(
            latex: latex,
            fontSize: fontSize,
            isDarkMode: isDarkMode,
            displayStyle: displayStyle
        )
        guard let image = cache[key] else {
            MarkdownObservability.recordLatexCache(hit: false)
            return nil
        }
        // Move to end of access order (most recently used)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
        MarkdownObservability.recordLatexCache(hit: true)
        return image
    }

    /// Store a rendered image in the cache.
    ///
    /// If the cache exceeds its maximum size after insertion, the least recently
    /// used entry is evicted.
    ///
    /// - Parameters:
    ///   - image: The rendered image to cache.
    ///   - latex: The LaTeX formula string.
    ///   - fontSize: The font size used for rendering.
    ///   - isDarkMode: Whether the image was rendered for dark mode.
    ///   - displayStyle: Whether display (block) mode was used.
    public func set(
        _ image: MTImage,
        latex: String,
        fontSize: CGFloat,
        isDarkMode: Bool,
        displayStyle: Bool
    ) {
        let key = CacheKey(
            latex: latex,
            fontSize: fontSize,
            isDarkMode: isDarkMode,
            displayStyle: displayStyle
        )
        // If key already exists, remove it from access order
        if cache[key] != nil {
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
        cache[key] = image
        accessOrder.append(key)
        // Evict least recently used if over capacity
        while accessOrder.count > maxSize {
            let evictedKey = accessOrder.removeFirst()
            cache.removeValue(forKey: evictedKey)
        }
    }

    /// Remove all cached entries, freeing memory immediately.
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}
