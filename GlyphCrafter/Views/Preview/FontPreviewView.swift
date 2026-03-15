import SwiftUI
import PencilKit

struct FontPreviewView: View {
    @Environment(FontProjectStore.self) private var store
    @State private var previewText = "The quick brown fox jumps over the lazy dog"
    @State private var fontSize: CGFloat = 32
    @State private var showingAllGlyphs = false

    private var project: FontProject? {
        store.selectedProject
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Text input
                    previewInputSection

                    // Rendered preview
                    previewRenderSection

                    // Character map
                    characterMapSection
                }
                .padding()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Preview Input

    private var previewInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview Text")
                .font(.headline)

            TextField("Type to preview...", text: $previewText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            HStack {
                Text("Size")
                    .font(.subheadline)
                Slider(value: $fontSize, in: 16...72) {
                    Text("Font Size")
                }
                Text("\(Int(fontSize))pt")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 36)
            }

            // Quick text presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(presetTexts, id: \.self) { preset in
                        Button(preset) {
                            previewText = preset
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Rendered Preview

    private var previewRenderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rendered Preview")
                .font(.headline)

            GlyphTextRenderer(
                text: previewText,
                glyphs: project?.glyphs ?? [],
                fontSize: fontSize
            )
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Character Map

    private var characterMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Character Map")
                    .font(.headline)
                Spacer()
                Button(showingAllGlyphs ? "Show Drawn Only" : "Show All") {
                    showingAllGlyphs.toggle()
                }
                .font(.caption)
            }

            let displayGlyphs = showingAllGlyphs
                ? (project?.glyphs ?? [])
                : (project?.glyphs.filter(\.hasDrawing) ?? [])

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 4) {
                ForEach(displayGlyphs) { glyph in
                    VStack(spacing: 2) {
                        if glyph.hasDrawing {
                            GlyphPathPreview(pathData: glyph.pathData)
                                .frame(width: 36, height: 36)
                        } else {
                            Text(glyph.character)
                                .font(.system(size: 20, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 36, height: 36)
                        }
                        Text(String(format: "U+%04X", glyph.unicodeScalar))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                    .background(
                        glyph.hasDrawing ? Color.accentColor.opacity(0.08) : Color(.systemGray6),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
            }
        }
    }

    // MARK: - Presets

    private var presetTexts: [String] {
        [
            "The quick brown fox jumps over the lazy dog",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "abcdefghijklmnopqrstuvwxyz",
            "0123456789",
            "Hello, World!",
            "Pack my box with five dozen liquor jugs",
        ]
    }
}

// MARK: - Glyph Text Renderer

struct GlyphTextRenderer: View {
    let text: String
    let glyphs: [Glyph]
    let fontSize: CGFloat

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 16
            let y: CGFloat = size.height / 2

            for char in text {
                let charStr = String(char)
                guard let scalar = char.unicodeScalars.first else { continue }

                if let glyph = glyphs.first(where: {
                    $0.unicodeScalar == scalar.value && $0.hasDrawing
                }) {
                    // Render the custom glyph
                    if let drawing = try? PKDrawing(data: glyph.pathData) {
                        let glyphSize = fontSize * 1.2
                        let scale = glyphSize / 512.0
                        let rect = CGRect(
                            x: x,
                            y: y - glyphSize * 0.6,
                            width: glyphSize,
                            height: glyphSize
                        )

                        for stroke in drawing.strokes {
                            var path = Path()
                            let points = stroke.path
                            guard points.count >= 2 else { continue }

                            path.move(to: CGPoint(
                                x: rect.origin.x + points[0].location.x * scale,
                                y: rect.origin.y + points[0].location.y * scale
                            ))
                            for i in 1..<points.count {
                                path.addLine(to: CGPoint(
                                    x: rect.origin.x + points[i].location.x * scale,
                                    y: rect.origin.y + points[i].location.y * scale
                                ))
                            }
                            context.stroke(path, with: .color(.primary), lineWidth: max(1, stroke.ink.color == .white ? 0 : 1.5))
                        }
                        x += glyphSize * 0.7
                    }
                } else if char == " " {
                    x += fontSize * 0.4
                } else {
                    // Fallback: render with system font
                    let text = Text(charStr)
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.4))
                    context.draw(
                        context.resolve(text),
                        at: CGPoint(x: x + fontSize * 0.3, y: y),
                        anchor: .leading
                    )
                    x += fontSize * 0.65
                }

                if x > size.width - 16 {
                    break
                }
            }
        }
    }
}
