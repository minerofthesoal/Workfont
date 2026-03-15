import SwiftUI
import PencilKit

struct GlyphEditorView: View {
    @Environment(FontProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager

    let glyph: Glyph
    let projectID: UUID

    @State private var currentTool: EditorTool = .pen
    @State private var brushSize: CGFloat = 4.0
    @State private var drawing = PKDrawing()
    @State private var showGuides = true
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero
    @State private var hasChanges = false
    @State private var showingDiscardAlert = false
    @State private var showingAISheet = false
    @State private var snapToGrid = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                editorToolbar

                ZStack {
                    Color(.systemBackground)

                    if showGuides {
                        GlyphGuideOverlay(showLabels: canvasScale > 1.2)
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
                .offset(canvasOffset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            canvasScale = min(max(value.magnification, 0.5), 4.0)
                        }
                )
                .simultaneousGesture(
                    canvasScale > 1.0
                        ? DragGesture()
                            .onChanged { value in
                                canvasOffset = value.translation
                            }
                        : nil
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        canvasScale = 1.0
                        canvasOffset = .zero
                    }
                }

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
                    .disabled(!hasChanges)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
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

                // Grid toggle
                Button {
                    showGuides.toggle()
                } label: {
                    Image(systemName: showGuides ? "grid" : "grid.circle")
                        .font(.title3)
                        .foregroundStyle(showGuides ? .accentColor : .secondary)
                        .frame(width: 40, height: 40)
                }

                // Snap toggle
                Button {
                    snapToGrid.toggle()
                } label: {
                    Image(systemName: snapToGrid ? "rectangle.grid.3x3.fill" : "rectangle.grid.3x3")
                        .font(.title3)
                        .foregroundStyle(snapToGrid ? .accentColor : .secondary)
                        .frame(width: 40, height: 40)
                }

                Divider().frame(height: 30)

                // Undo
                Button {
                    undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 40, height: 40)
                }
                .disabled(!(undoManager?.canUndo ?? false))

                // Redo
                Button {
                    undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .frame(width: 40, height: 40)
                }
                .disabled(!(undoManager?.canRedo ?? false))

                Divider().frame(height: 30)

                // Clear
                Button {
                    drawing = PKDrawing()
                    hasChanges = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Brush Size Control

    private var brushSizeControl: some View {
        HStack {
            Circle()
                .fill(Color.primary)
                .frame(width: 4, height: 4)
            Slider(value: $brushSize, in: 1...20) {
                Text("Brush Size")
            }
            Circle()
                .fill(Color.primary)
                .frame(width: 16, height: 16)
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
    var showLabels: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, size in
                let guideColor = Color.blue.opacity(0.15)
                let strongGuide = Color.blue.opacity(0.25)

                struct Guide {
                    let y: CGFloat
                    let name: String
                    let strong: Bool
                }

                let guides: [Guide] = [
                    Guide(y: h * 0.1, name: "Ascender", strong: false),
                    Guide(y: h * 0.2, name: "Cap Height", strong: true),
                    Guide(y: h * 0.45, name: "x-height", strong: true),
                    Guide(y: h * 0.75, name: "Baseline", strong: true),
                    Guide(y: h * 0.9, name: "Descender", strong: false),
                ]

                for guide in guides {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: guide.y))
                    path.addLine(to: CGPoint(x: w, y: guide.y))
                    context.stroke(
                        path,
                        with: .color(guide.strong ? strongGuide : guideColor),
                        style: StrokeStyle(
                            lineWidth: guide.strong ? 1.5 : 0.75,
                            dash: guide.strong ? [6, 4] : [3, 5]
                        )
                    )
                }

                // Side bearings
                let leftBearing = w * 0.1
                let rightBearing = w * 0.9
                for x in [leftBearing, rightBearing] {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                    context.stroke(path, with: .color(guideColor), style: StrokeStyle(lineWidth: 0.75, dash: [4, 4]))
                }

                // Center vertical
                var centerPath = Path()
                centerPath.move(to: CGPoint(x: w / 2, y: 0))
                centerPath.addLine(to: CGPoint(x: w / 2, y: h))
                context.stroke(centerPath, with: .color(guideColor.opacity(0.5)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 6]))
            }

            if showLabels {
                ForEach(
                    [
                        (0.2, "Cap"), (0.45, "x"), (0.75, "Base"), (0.9, "Desc")
                    ] as [(CGFloat, String)],
                    id: \.1
                ) { yFrac, label in
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundStyle(Color.blue.opacity(0.4))
                        .position(x: 20, y: h * yFrac - 8)
                }
            }
        }
    }
}
