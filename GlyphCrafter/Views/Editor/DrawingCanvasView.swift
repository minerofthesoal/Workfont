import SwiftUI
import PencilKit

// MARK: - Drawing Canvas (PencilKit Wrapper)

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var tool: EditorTool
    var brushSize: CGFloat
    var onChange: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.overrideUserInterfaceStyle = .light
        canvas.tool = makePKTool()
        canvas.isScrollEnabled = false

        // Enable finger drawing alongside pencil
        canvas.drawingPolicy = .anyInput

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Only update tool, don't replace drawing mid-edit
        uiView.tool = makePKTool()

        // Sync drawing if it was cleared
        if drawing.strokes.isEmpty && !uiView.drawing.strokes.isEmpty {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func makePKTool() -> PKTool {
        switch tool {
        case .pen:
            return PKInkingTool(.pen, color: .black, width: brushSize)
        case .eraser:
            return PKEraserTool(.bitmap, width: brushSize * 3)
        case .select:
            return PKLassoTool()
        case .move:
            return PKInkingTool(.pen, color: .black, width: brushSize)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: DrawingCanvasView

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onChange()
        }
    }
}
