import SwiftUI

@main
struct GlyphCrafterApp: App {
    @State private var store = FontProjectStore()
    @State private var llmService = LocalLLMService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(llmService)
        }
    }
}
