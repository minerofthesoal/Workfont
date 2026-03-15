import SwiftUI

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
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(GlyphCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Completion bar
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

                // Glyph grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filteredGlyphs) { glyph in
                            GlyphCell(glyph: glyph)
                                .onTapGesture {
                                    selectedGlyph = glyph
                                    showingEditor = true
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
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
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
                    // Show a preview of the drawn glyph
                    GlyphPathPreview(pathData: glyph.pathData)
                        .padding(8)
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

// MARK: - Glyph Path Preview

struct GlyphPathPreview: View {
    let pathData: Data

    var body: some View {
        Canvas { context, size in
            guard let drawing = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: PKDrawingWrapper.self, from: pathData
            ) else { return }

            let paths = drawing.paths
            for pathInfo in paths {
                var path = Path()
                let points = pathInfo.points
                guard !points.isEmpty else { continue }

                let scaleX = size.width / 512
                let scaleY = size.height / 512

                path.move(to: CGPoint(x: points[0].x * scaleX, y: points[0].y * scaleY))
                for i in 1..<points.count {
                    path.addLine(to: CGPoint(x: points[i].x * scaleX, y: points[i].y * scaleY))
                }
                context.stroke(path, with: .color(.primary), lineWidth: max(1, pathInfo.lineWidth * scaleX))
            }
        }
    }
}
