import SwiftUI

@main
struct GlyphCrafterApp: App {
    @State private var store = FontProjectStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
