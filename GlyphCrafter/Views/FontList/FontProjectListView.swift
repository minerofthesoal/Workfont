import SwiftUI

struct FontProjectListView: View {
    @Environment(FontProjectStore.self) private var store
    @Binding var selectedTab: ContentView.AppTab
    @State private var showingNewProject = false
    @State private var newProjectName = ""
    @State private var searchText = ""

    private var filteredProjects: [FontProject] {
        if searchText.isEmpty {
            return store.projects
        }
        return store.projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No Font Projects", systemImage: "textformat.alt")
                    } description: {
                        Text("Tap the + button to create your first custom font.")
                    } actions: {
                        Button("Create Font") {
                            showingNewProject = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(filteredProjects) { project in
                            FontProjectRow(project: project)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.selectedProjectID = project.id
                                    selectedTab = .editor
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.deleteProject(project)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        store.duplicateProject(project)
                                    } label: {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }
                                    .tint(.blue)
                                }
                                .listRowBackground(
                                    store.selectedProjectID == project.id
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear
                                )
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search fonts")
                }
            }
            .navigationTitle("GlyphCrafter")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Font Project", isPresented: $showingNewProject) {
                TextField("Font Name", text: $newProjectName)
                Button("Create") {
                    let name = newProjectName.isEmpty ? "Untitled Font" : newProjectName
                    _ = store.createProject(name: name)
                    newProjectName = ""
                    selectedTab = .editor
                }
                Button("Cancel", role: .cancel) {
                    newProjectName = ""
                }
            } message: {
                Text("Enter a name for your new font.")
            }
        }
    }
}

// MARK: - Font Project Row

struct FontProjectRow: View {
    let project: FontProject

    var body: some View {
        HStack(spacing: 16) {
            // Glyph preview thumbnail
            GlyphThumbnailGrid(project: project)
                .frame(width: 56, height: 56)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                Text(project.familyName + " " + project.styleName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ProgressView(value: project.completionPercentage)
                        .frame(width: 80)
                    Text("\(Int(project.completionPercentage * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(project.modifiedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Glyph Thumbnail Grid

struct GlyphThumbnailGrid: View {
    let project: FontProject

    var body: some View {
        let drawn = project.glyphs.filter(\.hasDrawing).prefix(4)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
            ForEach(Array(drawn.prefix(4))) { glyph in
                Text(glyph.character)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Fill remaining slots
            if drawn.count < 4 {
                ForEach(0..<(4 - drawn.count), id: \.self) { _ in
                    Text("?")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(4)
    }
}
