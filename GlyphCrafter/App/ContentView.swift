import SwiftUI

struct ContentView: View {
    @Environment(FontProjectStore.self) private var store
    @State private var selectedTab: AppTab = .projects

    enum AppTab: String, CaseIterable {
        case projects = "Projects"
        case editor = "Editor"
        case ai = "AI Generate"
        case preview = "Preview"
        case export = "Export"

        var icon: String {
            switch self {
            case .projects: return "folder"
            case .editor: return "pencil.and.outline"
            case .ai: return "sparkles"
            case .preview: return "eye"
            case .export: return "square.and.arrow.up"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.projects.rawValue, systemImage: AppTab.projects.icon, value: .projects) {
                FontProjectListView(selectedTab: $selectedTab)
            }

            Tab(AppTab.editor.rawValue, systemImage: AppTab.editor.icon, value: .editor) {
                if store.selectedProject != nil {
                    GlyphGridView(selectedTab: $selectedTab)
                } else {
                    noProjectSelectedView
                }
            }

            Tab(AppTab.ai.rawValue, systemImage: AppTab.ai.icon, value: .ai) {
                if store.selectedProject != nil {
                    AIFontGeneratorView()
                } else {
                    noProjectSelectedView
                }
            }

            Tab(AppTab.preview.rawValue, systemImage: AppTab.preview.icon, value: .preview) {
                if store.selectedProject != nil {
                    FontPreviewView()
                } else {
                    noProjectSelectedView
                }
            }

            Tab(AppTab.export.rawValue, systemImage: AppTab.export.icon, value: .export) {
                if store.selectedProject != nil {
                    ExportView()
                } else {
                    noProjectSelectedView
                }
            }
        }
        .tint(Color.accentColor)
    }

    private var noProjectSelectedView: some View {
        ContentUnavailableView {
            Label("No Font Selected", systemImage: "textformat.alt")
        } description: {
            Text("Create or select a font project to get started.")
        } actions: {
            Button("Go to Projects") {
                selectedTab = .projects
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
        .environment(FontProjectStore())
        .environment(LocalLLMService())
}
