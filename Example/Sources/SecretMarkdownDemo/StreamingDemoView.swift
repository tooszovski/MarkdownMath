import SwiftUI
import SecretMarkdownUI
import SecretMarkdownHighlight

private let streamingResponse = """
## Analysis Complete

The results show a **significant improvement** in performance:

1. Latency reduced by *42%*
2. Throughput increased to `1200 req/s`
3. Memory usage dropped by ~~30%~~ 25%

### Key Formula

The optimization follows $O(n \\log n)$ complexity:

$$T(n) = 2T\\left(\\frac{n}{2}\\right) + O(n)$$

```swift
func mergeSort(_ array: [Int]) -> [Int] {
    guard array.count > 1 else { return array }
    let mid = array.count / 2
    let left = mergeSort(Array(array[..<mid]))
    let right = mergeSort(Array(array[mid...]))
    return merge(left, right)
}
```

> This approach is optimal for large datasets.

| Metric | Before | After |
|--------|--------|-------|
| P50 | 120ms | 70ms |
| P99 | 450ms | 260ms |
"""

struct StreamingDemoView: View {
    @State private var displayedText = ""
    @State private var isStreaming = false
    @State private var streamingTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("\(displayedText.count) / \(streamingResponse.count) chars")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(isStreaming ? "Streaming..." : "Idle")
                        .foregroundStyle(isStreaming ? .green : .secondary)
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    if !displayedText.isEmpty {
                        MarkdownView(text: displayedText, isStreaming: isStreaming)
                            .markdownTheme(.compact)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "text.cursor")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Content")
                                .font(.title3)
                            Text("Tap Start to begin streaming demo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .enableCodeHighlighting()

                Divider()

                HStack(spacing: 16) {
                    Button(action: startStreaming) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isStreaming)

                    Button(action: reset) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Streaming")
        }
    }

    private func startStreaming() {
        reset()
        isStreaming = true

        streamingTask = Task {
            var characterIndex = 0
            while characterIndex < streamingResponse.count {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }

                characterIndex = min(characterIndex + 5, streamingResponse.count)
                let stringIndex = streamingResponse.index(
                    streamingResponse.startIndex,
                    offsetBy: characterIndex
                )
                displayedText = String(streamingResponse[..<stringIndex])
            }
            isStreaming = false
        }
    }

    private func reset() {
        streamingTask?.cancel()
        streamingTask = nil
        displayedText = ""
        isStreaming = false
    }
}
