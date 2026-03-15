import SwiftUI
import PencilKit

struct GlyphGridView: View {
    @Environment(FontProjectStore.self) private var store
    @Binding var selectedTab: ContentView.AppTab
    @State private var selectedCategory: GlyphCategory = .uppercase
    @State private var selectedGlyph: Glyph?
    @State private var showingEditor = false
    @State private var showingSettings = false

    private var project: FontProject? {
        store.selectedProject
    }

    private var filteredGlyphs: [Glyph] {
        guard let project else { return [] }
        return selectedCategory.filter(project.glyphs)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(GlyphCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if let project {
                    let catGlyphs = selectedCategory.filter(project.glyphs)
                    let drawn = catGlyphs.filter(\.hasDrawing).count
                    HStack {
                        Text("\(drawn)/\(catGlyphs.count) drawn")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView(value: catGlyphs.isEmpty ? 0 : Double(drawn) / Double(catGlyphs.count))
                            .frame(width: 100)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filteredGlyphs) { glyph in
                            GlyphCell(glyph: glyph)
                                .onTapGesture {
                                    selectedGlyph = glyph
                                    showingEditor = true
                                }
                                .contextMenu {
                                    if glyph.hasDrawing {
                                        Button(role: .destructive) {
                                            clearGlyph(glyph)
                                        } label: {
                                            Label("Clear Drawing", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(project?.name ?? "Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Font Settings", systemImage: "gearshape")
                        }
                        Button {
                            selectedTab = .ai
                        } label: {
                            Label("AI Generate", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingEditor) {
                if let glyph = selectedGlyph, let project {
                    GlyphEditorView(
                        glyph: glyph,
                        projectID: project.id
                    )
                }
            }
            .sheet(isPresented: $showingSettings) {
                if project != nil {
                    FontSettingsView()
                }
            }
        }
    }

    private func clearGlyph(_ glyph: Glyph) {
        guard let project else { return }
        var cleared = glyph
        cleared.pathData = Data()
        cleared.lastModified = Date()
        store.updateGlyph(cleared, inProject: project.id)
    }
}

// MARK: - Glyph Cell

struct GlyphCell: View {
    let glyph: Glyph

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(glyph.hasDrawing ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                glyph.hasDrawing ? Color.accentColor.opacity(0.3) : Color(.systemGray4),
                                lineWidth: 1
                            )
                    )

                if glyph.hasDrawing {
                    GlyphPathPreview(pathData: glyph.pathData)
                        .padding(6)
                } else {
                    Text(glyph.character)
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Text(glyph.character == " " ? "SPC" : glyph.character)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Glyph Path Preview (PencilKit-based)

struct GlyphPathPreview: View {
    let pathData: Data

    var body: some View {
        GeometryReader { geo in
            if let drawing = try? PKDrawing(data: pathData), !drawing.strokes.isEmpty {
                let bounds = drawing.bounds
                let image = renderDrawing(drawing, bounds: bounds, targetSize: geo.size)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private func renderDrawing(_ drawing: PKDrawing, bounds: CGRect, targetSize: CGSize) -> UIImage {
        guard !bounds.isEmpty else {
            return UIImage()
        }

        let padding: CGFloat = 4
        let availableWidth = targetSize.width - padding * 2
        let availableHeight = targetSize.height - padding * 2

        let scaleX = availableWidth / bounds.width
        let scaleY = availableHeight / bounds.height
        let scale = min(scaleX, scaleY)

        let renderWidth = bounds.width * scale
        let renderHeight = bounds.height * scale
        let offsetX = (targetSize.width - renderWidth) / 2
        let offsetY = (targetSize.height - renderHeight) / 2

        let imageRect = CGRect(
            x: bounds.origin.x - (offsetX / scale),
            y: bounds.origin.y - (offsetY / scale),
            width: targetSize.width / scale,
            height: targetSize.height / scale
        )

        return drawing.image(from: imageRect, scale: scale)
    }
}
