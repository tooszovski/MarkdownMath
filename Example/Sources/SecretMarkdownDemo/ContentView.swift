import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StaticDemoView()
                .tabItem {
                    Label("Static", systemImage: "doc.richtext")
                }

            StreamingDemoView()
                .tabItem {
                    Label("Streaming", systemImage: "text.badge.plus")
                }

            ThemeDemoView()
                .tabItem {
                    Label("Themes", systemImage: "paintpalette")
                }
        }
    }
}
