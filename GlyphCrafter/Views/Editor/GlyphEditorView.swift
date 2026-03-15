import SwiftUI
import PencilKit

struct GlyphEditorView: View {
    @Environment(FontProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let glyph: Glyph
    let projectID: UUID

    @State private var currentTool: EditorTool = .pen
    @State private var brushSize: CGFloat = 4.0
    @State private var drawing = PKDrawing()
    @State private var showGuides = true
    @State private var canvasScale: CGFloat = 1.0
    @State private var hasChanges = false
    @State private var showingDiscardAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar strip
                editorToolbar

                // Canvas area
                ZStack {
                    Color(.systemBackground)

                    if showGuides {
                        GlyphGuideOverlay()
                    }

                    DrawingCanvasView(
                        drawing: $drawing,
                        tool: currentTool,
                        brushSize: brushSize,
                        onChange: { hasChanges = true }
                    )
                    .clipShape(Rectangle())
                }
                .aspectRatio(1, contentMode: .fit)
                .padding()
                .scaleEffect(canvasScale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            canvasScale = min(max(value.magnification, 0.5), 3.0)
                        }
                )

                // Brush size slider
                if currentTool == .pen || currentTool == .eraser {
                    brushSizeControl
                }

                Spacer()
            }
            .navigationTitle("Editing: \(glyph.character == " " ? "Space" : glyph.character)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGlyph()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes to this glyph.")
            }
            .onAppear(perform: loadExistingDrawing)
        }
    }

    // MARK: - Editor Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 16) {
            ForEach(EditorTool.allCases, id: \.self) { tool in
                Button {
                    currentTool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.title3)
                        .foregroundStyle(currentTool == tool ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(
                            currentTool == tool ? Color.accentColor : Color(.systemGray5),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
            }

            Divider().frame(height: 30)

            Button {
                showGuides.toggle()
            } label: {
                Image(systemName: showGuides ? "grid" : "grid.circle")
                    .font(.title3)
                    .foregroundStyle(showGuides ? .accentColor : .secondary)
            }

            Spacer()

            Button {
                drawing = PKDrawing()
                hasChanges = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }

            Button {
                // Undo via PencilKit is handled by the canvas
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Brush Size Control

    private var brushSizeControl: some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
            Slider(value: $brushSize, in: 1...20) {
                Text("Brush Size")
            }
            Image(systemName: "circle.fill")
                .font(.system(size: 16))
            Text(String(format: "%.0f", brushSize))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 30)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Save / Load

    private func loadExistingDrawing() {
        guard !glyph.pathData.isEmpty else { return }
        if let existingDrawing = try? PKDrawing(data: glyph.pathData) {
            drawing = existingDrawing
        }
    }

    private func saveGlyph() {
        var updatedGlyph = glyph
        updatedGlyph.pathData = drawing.dataRepresentation()
        updatedGlyph.lastModified = Date()

        // Calculate bounding box for metrics
        let bounds = drawing.bounds
        if !bounds.isEmpty {
            updatedGlyph.width = bounds.width
            updatedGlyph.height = bounds.height
            updatedGlyph.bearingX = bounds.origin.x
            updatedGlyph.bearingY = bounds.origin.y
            updatedGlyph.advance = bounds.width + bounds.origin.x + 20
        }

        store.updateGlyph(updatedGlyph, inProject: projectID)
    }
}

// MARK: - Guide Overlay

struct GlyphGuideOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, size in
                let guideColor = Color.blue.opacity(0.15)
                let baselineY = h * 0.75
                let capHeightY = h * 0.2
                let xHeightY = h * 0.45
                let descenderY = h * 0.9

                // Horizontal guides
                let guides: [(CGFloat, String)] = [
                    (capHeightY, "Cap"),
                    (xHeightY, "x-height"),
                    (baselineY, "Baseline"),
                    (descenderY, "Descender"),
                ]

                for (y, _) in guides {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                    context.stroke(path, with: .color(guideColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                // Side bearings
                let leftBearing = w * 0.1
                let rightBearing = w * 0.9
                for x in [leftBearing, rightBearing] {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                    context.stroke(path, with: .color(guideColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
        }
    }
}
