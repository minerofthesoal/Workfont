import SwiftUI
import PencilKit

// MARK: - AI Font Generator View

struct AIFontGeneratorView: View {
    @Environment(FontProjectStore.self) private var store
    @Environment(LocalLLMService.self) private var llm

    @State private var stylePrompt = ""
    @State private var selectedPreset: StylePreset? = nil
    @State private var generationScope: GenerationScope = .uppercase
    @State private var temperature: Float = 0.7
    @State private var generatedPreviews: [String: String] = [:]
    @State private var isGenerating = false
    @State private var showingApplyAlert = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    modelStatusCard
                    styleInputSection
                    scopeSection
                    generateButton
                    if !generatedPreviews.isEmpty {
                        previewGrid
                        applyButton
                    }
                    if let err = errorMessage {
                        errorBanner(err)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Font Generator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Model Status

    private var modelStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: modelStatusIcon)
                    .font(.title2)
                    .foregroundStyle(modelStatusColor)
                    .symbolEffect(.pulse, isActive: llm.state.isWorking)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Qwen3.5-2B (MLX)")
                        .font(.headline)
                    Text(llm.state.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if llm.state == .idle || llm.state.isError {
                    Button("Load Model") {
                        Task { await llm.loadModel() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if llm.state == .ready {
                    Button("Unload") {
                        llm.unloadModel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }

            if case .downloading(let progress) = llm.state {
                ProgressView(value: progress)
                    .tint(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var modelStatusIcon: String {
        switch llm.state {
        case .idle: return "cpu"
        case .downloading: return "arrow.down.circle"
        case .loading: return "memorychip"
        case .ready: return "checkmark.circle.fill"
        case .generating: return "sparkles"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var modelStatusColor: Color {
        switch llm.state {
        case .ready: return .green
        case .error: return .red
        case .generating: return .purple
        default: return .accentColor
        }
    }

    // MARK: - Style Input

    private var styleInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font Style")
                .font(.headline)

            TextField("Describe your font style...", text: $stylePrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Text("Presets")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StylePreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                            stylePrompt = preset.prompt
                        } label: {
                            VStack(spacing: 4) {
                                Text(preset.icon)
                                    .font(.title2)
                                Text(preset.rawValue)
                                    .font(.caption2)
                            }
                            .frame(width: 72, height: 60)
                            .background(
                                selectedPreset == preset
                                    ? Color.accentColor.opacity(0.15)
                                    : Color(.systemGray6),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        selectedPreset == preset ? Color.accentColor : .clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Text("Creativity")
                    .font(.subheadline)
                Slider(value: $temperature, in: 0.1...1.5) {
                    Text("Temperature")
                }
                Text(String(format: "%.1f", temperature))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 30)
            }
        }
    }

    // MARK: - Scope

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Generate")
                .font(.headline)

            Picker("Scope", selection: $generationScope) {
                ForEach(GenerationScope.allCases, id: \.self) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Text(generationScope.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isGenerating ? llm.state.statusText : "Generate with AI")
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .controlSize(.large)
        .disabled(!llm.isReady || stylePrompt.isEmpty || isGenerating)
    }

    // MARK: - Preview Grid

    private var previewGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Generated Glyphs")
                    .font(.headline)
                Spacer()
                Text("\(generatedPreviews.count) glyphs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 8) {
                ForEach(generatedPreviews.sorted(by: { $0.key < $1.key }), id: \.key) { char, svg in
                    VStack(spacing: 4) {
                        AIGlyphPreview(svgOutput: svg)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        Text(char)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Apply Button

    private var applyButton: some View {
        Button {
            showingApplyAlert = true
        } label: {
            Label("Apply to Current Font", systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .controlSize(.large)
        .disabled(store.selectedProject == nil)
        .alert("Apply AI Glyphs?", isPresented: $showingApplyAlert) {
            Button("Apply (Overwrite Existing)", role: .destructive) {
                applyToProject()
            }
            Button("Apply (Skip Existing)") {
                applyToProject(skipExisting: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will add \(generatedPreviews.count) AI-generated glyphs to \"\(store.selectedProject?.name ?? "")\".")
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button("Dismiss") { errorMessage = nil }
                .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Generation Logic

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        generatedPreviews = [:]

        let chars = generationScope.characters

        do {
            generatedPreviews = try await llm.generateBatchGlyphs(
                characters: chars,
                style: stylePrompt,
                temperature: temperature
            ) { char, current, total in
                // Progress is tracked via llm.state
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    private func applyToProject(skipExisting: Bool = false) {
        guard var project = store.selectedProject else { return }

        for (char, svg) in generatedPreviews {
            guard let glyphIndex = project.glyphs.firstIndex(where: { $0.character == char }) else {
                continue
            }

            if skipExisting && project.glyphs[glyphIndex].hasDrawing {
                continue
            }

            if let pathData = try? SVGToPathConverter.convert(svgOutput: svg) {
                project.glyphs[glyphIndex].pathData = pathData
                project.glyphs[glyphIndex].lastModified = Date()
            }
        }

        store.selectedProject = project
    }
}

// MARK: - AI Glyph Preview

struct AIGlyphPreview: View {
    let svgOutput: String

    var body: some View {
        Canvas { context, size in
            guard let cgPath = try? SVGToPathConverter.convertToCGPath(svgOutput: svgOutput) else {
                return
            }

            let bounds = cgPath.boundingBox
            guard !bounds.isEmpty else { return }

            let scaleX = (size.width - 8) / bounds.width
            let scaleY = (size.height - 8) / bounds.height
            let scale = min(scaleX, scaleY)

            let offsetX = (size.width - bounds.width * scale) / 2 - bounds.origin.x * scale
            let offsetY = (size.height - bounds.height * scale) / 2 - bounds.origin.y * scale

            var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
                .scaledBy(x: scale, y: scale)

            if let scaledPath = cgPath.copy(using: &transform) {
                context.fill(Path(scaledPath), with: .color(.primary))
            }
        }
    }
}

// MARK: - Style Presets

enum StylePreset: String, CaseIterable, Identifiable {
    case handwritten = "Handwritten"
    case serif = "Serif"
    case sansSerif = "Sans Serif"
    case monospace = "Monospace"
    case brush = "Brush"
    case pixel = "Pixel"
    case gothic = "Gothic"
    case rounded = "Rounded"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .handwritten: return "🖊"
        case .serif: return "🅰"
        case .sansSerif: return "🔤"
        case .monospace: return "💻"
        case .brush: return "🖌"
        case .pixel: return "👾"
        case .gothic: return "🏰"
        case .rounded: return "⭕"
        }
    }

    var prompt: String {
        switch self {
        case .handwritten:
            return "Casual handwritten style with natural stroke variation, slightly slanted, ink-pen feel with organic curves"
        case .serif:
            return "Classic serif typeface with elegant thin/thick stroke contrast, bracketed serifs, balanced proportions like Times New Roman"
        case .sansSerif:
            return "Clean geometric sans-serif with uniform stroke weight, modern minimalist feel like Helvetica or Inter"
        case .monospace:
            return "Fixed-width monospace font with uniform character widths, clear distinction between similar characters (0/O, 1/l/I), coding-optimized"
        case .brush:
            return "Bold brush stroke calligraphy with dramatic thick/thin transitions, energetic and expressive with dry brush texture"
        case .pixel:
            return "8-bit retro pixel art font with blocky geometric shapes on a grid, sharp right angles, nostalgic video game aesthetic"
        case .gothic:
            return "Blackletter gothic style with ornate angular strokes, dramatic vertical emphasis, medieval manuscript feel with sharp diamond terminals"
        case .rounded:
            return "Soft rounded sans-serif with circular stroke terminals, friendly and approachable, bubbly with generous curves like Nunito"
        }
    }
}

// MARK: - Generation Scope

enum GenerationScope: String, CaseIterable {
    case sample = "Sample"
    case uppercase = "A-Z"
    case lowercase = "a-z"
    case digits = "0-9"
    case full = "Full Set"

    var label: String { rawValue }

    var description: String {
        switch self {
        case .sample: return "Generate 5 sample characters to preview the style"
        case .uppercase: return "Generate all 26 uppercase letters"
        case .lowercase: return "Generate all 26 lowercase letters"
        case .digits: return "Generate digits 0-9"
        case .full: return "Generate uppercase, lowercase, and digits (62 characters)"
        }
    }

    var characters: [String] {
        switch self {
        case .sample: return ["A", "B", "g", "k", "7"]
        case .uppercase: return (0x41...0x5A).map { String(UnicodeScalar($0)!) }
        case .lowercase: return (0x61...0x7A).map { String(UnicodeScalar($0)!) }
        case .digits: return (0x30...0x39).map { String(UnicodeScalar($0)!) }
        case .full:
            return (0x41...0x5A).map { String(UnicodeScalar($0)!) } +
                   (0x61...0x7A).map { String(UnicodeScalar($0)!) } +
                   (0x30...0x39).map { String(UnicodeScalar($0)!) }
        }
    }
}
