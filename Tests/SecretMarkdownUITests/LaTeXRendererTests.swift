import Testing
@testable import SecretMarkdownUI

@MainActor
@Suite("LaTeXRenderer")
struct LaTeXRendererTests {

    @Test("renders simple formula to non-nil image")
    func renderSimpleFormula() {
        let image = LaTeXRenderer.render("x^2")
        #expect(image != nil, "Expected a non-nil image for valid LaTeX")
    }

    @Test("returns nil for invalid LaTeX")
    func renderInvalidLaTeX() {
        // An unclosed group should fail to parse
        let image = LaTeXRenderer.render("{")
        #expect(image == nil, "Expected nil for invalid LaTeX")
    }
}
