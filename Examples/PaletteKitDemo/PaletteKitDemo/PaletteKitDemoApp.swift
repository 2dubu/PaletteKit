import SwiftUI

@main
struct PaletteKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Extract", systemImage: "paintpalette") }
                AsyncLoadView()
                    .tabItem { Label("Async", systemImage: "icloud.and.arrow.down") }
            }
        }
    }
}
