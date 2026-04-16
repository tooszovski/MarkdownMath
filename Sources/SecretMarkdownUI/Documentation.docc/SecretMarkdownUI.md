# ``SecretMarkdownUI``

Render Markdown with LaTeX support in SwiftUI.

## Overview

SecretMarkdown renders Markdown text with embedded LaTeX formulas as native SwiftUI views. Designed for AI chat interfaces with streaming support.

Key features:

- Full CommonMark + GFM support (tables, task lists, strikethrough)
- LaTeX formula rendering via CoreGraphics (no JavaScript overhead)
- Streaming mode for incremental AI chat token rendering
- Theming system with environment-based configuration
- Pluggable syntax highlighting for code blocks
- VoiceOver accessibility for LaTeX formulas

## Topics

### Essentials
- ``MarkdownView``
- ``MarkdownTheme``

### LaTeX
- ``LaTeXRenderer``
- ``LaTeXCache``

### Theming
- ``MarkdownTheme``
- ``CodeTheme``
- ``CodeHighlighterFunction``
