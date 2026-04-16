import SwiftUI
import SwiftMath

/// Renders LaTeX strings to platform-native images using SwiftMath (pure CoreGraphics, no JavaScript).
///
/// `LaTeXRenderer` provides static methods for converting LaTeX formula strings
/// into `UIImage` (iOS) or `NSImage` (macOS). The second overload of ``render(_:fontSize:textColor:displayStyle:isDarkMode:)``
/// integrates with ``LaTeXCache`` for automatic LRU caching.
///
/// All rendering happens on the main actor because SwiftMath relies on CoreGraphics
/// contexts that must be accessed from the main thread.
@MainActor
public struct LaTeXRenderer {

    /// Render a LaTeX formula to a platform-native image (legacy API, no cache).
    /// - Parameters:
    ///   - latex: The LaTeX string to render (e.g. `"x^2 + y^2 = z^2"`).
    ///   - fontSize: Font size in points. Default is 20.
    ///   - textColor: Text color for the rendered formula. Default is black.
    /// - Returns: A rendered `MTImage` (UIImage on iOS / NSImage on macOS), or `nil` on failure.
    public static func render(
        _ latex: String,
        fontSize: CGFloat = 20,
        textColor: MTColor = .black
    ) -> MTImage? {
        let mathImage = MTMathImage(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor
        )
        let (_, image) = mathImage.asImage()
        return image
    }

    /// Render a LaTeX formula to a platform-native image with caching and display style support.
    /// - Parameters:
    ///   - latex: The LaTeX string to render.
    ///   - fontSize: Font size in points. Default is 20.
    ///   - textColor: Text color for the rendered formula.
    ///   - displayStyle: If `true`, uses display mode (larger fractions/limits).
    ///                   If `false`, uses text mode (inline-sized).
    ///   - isDarkMode: Whether the current color scheme is dark. Used for cache keying.
    /// - Returns: A rendered `MTImage`, or `nil` on failure.
    public static func render(
        _ latex: String,
        fontSize: CGFloat = 20,
        textColor: MTColor,
        displayStyle: Bool,
        isDarkMode: Bool
    ) -> MTImage? {
        let cache = LaTeXCache.shared

        // Check cache first
        if let cached = cache.get(
            latex: latex,
            fontSize: fontSize,
            isDarkMode: isDarkMode,
            displayStyle: displayStyle
        ) {
            return cached
        }

        let labelMode: MTMathUILabelMode = displayStyle ? .display : .text
        let mathImage = MTMathImage(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            labelMode: labelMode
        )
        let (_, image) = mathImage.asImage()

        if let image {
            cache.set(
                image,
                latex: latex,
                fontSize: fontSize,
                isDarkMode: isDarkMode,
                displayStyle: displayStyle
            )
        }

        return image
    }

    /// Render a LaTeX formula and return a SwiftUI `Image`.
    /// - Parameters:
    ///   - latex: The LaTeX string to render.
    ///   - fontSize: Font size in points.
    ///   - textColor: Text color for the rendered formula.
    ///   - displayStyle: If `true`, uses display mode; if `false`, text mode.
    ///   - isDarkMode: Whether the current color scheme is dark.
    /// - Returns: A SwiftUI `Image`, or `nil` on failure.
    public static func renderImage(
        _ latex: String,
        fontSize: CGFloat = 20,
        textColor: MTColor,
        displayStyle: Bool,
        isDarkMode: Bool
    ) -> Image? {
        guard let mtImage = render(
            latex,
            fontSize: fontSize,
            textColor: textColor,
            displayStyle: displayStyle,
            isDarkMode: isDarkMode
        ) else {
            return nil
        }
        #if canImport(UIKit)
        return Image(uiImage: mtImage)
        #elseif canImport(AppKit)
        return Image(nsImage: mtImage)
        #endif
    }
}
