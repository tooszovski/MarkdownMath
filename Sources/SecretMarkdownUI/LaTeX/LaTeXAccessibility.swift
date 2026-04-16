import Foundation

/// Maps LaTeX formulas to natural language descriptions for VoiceOver.
enum LaTeXAccessibility {

    /// Generate a VoiceOver-friendly description of a LaTeX formula.
    static func describe(_ latex: String) -> String {
        var result = latex

        // \frac{X}{Y} → "X over Y"
        result = applyPattern(#"\\frac\{([^}]*)\}\{([^}]*)\}"#, in: result) { match in
            "\(match[1]) over \(match[2])"
        }

        // \sqrt[N]{X} → "Nth root of X" (must come before \sqrt{X})
        result = applyPattern(#"\\sqrt\[([^\]]*)\]\{([^}]*)\}"#, in: result) { match in
            "\(match[1])th root of \(match[2])"
        }

        // \sqrt{X} → "square root of X"
        result = applyPattern(#"\\sqrt\{([^}]*)\}"#, in: result) { match in
            "square root of \(match[1])"
        }

        // X^{2} or X^2 → "X squared" (special case)
        result = applyPattern(#"(\w)\^\{2\}"#, in: result) { match in
            "\(match[1]) squared"
        }
        result = applyPattern(#"(\w)\^2(?![0-9])"#, in: result) { match in
            "\(match[1]) squared"
        }

        // X^{3} or X^3 → "X cubed" (special case)
        result = applyPattern(#"(\w)\^\{3\}"#, in: result) { match in
            "\(match[1]) cubed"
        }
        result = applyPattern(#"(\w)\^3(?![0-9])"#, in: result) { match in
            "\(match[1]) cubed"
        }

        // X^{Y} → "X to the power of Y"
        result = applyPattern(#"(\w)\^\{([^}]*)\}"#, in: result) { match in
            "\(match[1]) to the power of \(match[2])"
        }

        // X^Y (single character exponent) → "X to the power of Y"
        result = applyPattern(#"(\w)\^(\w)"#, in: result) { match in
            "\(match[1]) to the power of \(match[2])"
        }

        // X_{Y} → "X sub Y"
        result = applyPattern(#"(\w)_\{([^}]*)\}"#, in: result) { match in
            "\(match[1]) sub \(match[2])"
        }

        // X_Y (single character subscript) → "X sub Y"
        result = applyPattern(#"(\w)_(\w)"#, in: result) { match in
            "\(match[1]) sub \(match[2])"
        }

        // Named commands → words
        let commandMappings: [(String, String)] = [
            (#"\sum"#, "sum"),
            (#"\prod"#, "product"),
            (#"\int"#, "integral"),
            (#"\infty"#, "infinity"),
            (#"\pi"#, "pi"),
            (#"\alpha"#, "alpha"),
            (#"\beta"#, "beta"),
            (#"\gamma"#, "gamma"),
            (#"\delta"#, "delta"),
            (#"\theta"#, "theta"),
            (#"\lambda"#, "lambda"),
            (#"\mu"#, "mu"),
            (#"\sigma"#, "sigma"),
            (#"\omega"#, "omega"),
            (#"\phi"#, "phi"),
            (#"\epsilon"#, "epsilon"),
            (#"\leq"#, "less than or equal to"),
            (#"\geq"#, "greater than or equal to"),
            (#"\neq"#, "not equal to"),
            (#"\approx"#, "approximately equal to"),
            (#"\times"#, "times"),
            (#"\div"#, "divided by"),
            (#"\pm"#, "plus or minus"),
            (#"\cdot"#, "dot"),
            (#"\rightarrow"#, "goes to"),
            (#"\to"#, "goes to"),
            (#"\Rightarrow"#, "implies"),
            (#"\forall"#, "for all"),
            (#"\exists"#, "there exists"),
            (#"\in"#, "in"),
            (#"\partial"#, "partial"),
            (#"\nabla"#, "nabla"),
        ]

        for (command, word) in commandMappings {
            // Match the command followed by a word boundary (not another letter)
            let escaped = NSRegularExpression.escapedPattern(for: command)
            result = applyPattern(escaped + #"(?![a-zA-Z])"#, in: result) { _ in
                word
            }
        }

        // Operators: = + -
        result = result.replacingOccurrences(of: "=", with: " equals ")
        result = result.replacingOccurrences(of: "+", with: " plus ")
        // Use regex to avoid replacing minus in words or negative numbers incorrectly
        result = applyPattern(#"(?<=\s)-(?=\s)"#, in: result) { _ in " minus " }
        // Also handle standalone minus (e.g., "a - b")
        result = applyPattern(#"(?<=\w)\s*-\s*(?=\w)"#, in: result) { _ in " minus " }

        // Strip remaining \commands
        result = applyPattern(#"\\[a-zA-Z]+"#, in: result) { _ in "" }

        // Strip braces
        result = result.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")

        // Clean up whitespace
        result = applyPattern(#"\s+"#, in: result) { _ in " " }
        result = result.trimmingCharacters(in: .whitespaces)

        return result
    }

    // MARK: - Private

    /// Apply a regex pattern and replace each match using a closure.
    /// The closure receives an array where index 0 is the full match,
    /// and subsequent indices are capture groups.
    private static func applyPattern(
        _ pattern: String,
        in string: String,
        replacement: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return string
        }
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))

        var result = string
        // Process matches in reverse to preserve ranges
        for match in matches.reversed() {
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                let range = match.range(at: i)
                if range.location != NSNotFound {
                    groups.append(nsString.substring(with: range))
                } else {
                    groups.append("")
                }
            }
            let replacementString = replacement(groups)
            let matchRange = match.range(at: 0)
            if let swiftRange = Range(matchRange, in: result) {
                result = result.replacingCharacters(in: swiftRange, with: replacementString)
            }
        }
        return result
    }
}
