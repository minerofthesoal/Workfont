import Foundation
import Observation

#if canImport(MLX)
import MLX
import MLXNN
import MLXRandom
import MLXLMCommon
import MLXLLM
#endif

// MARK: - Local LLM Service

/// On-device LLM service using MLX Swift to run Qwen3.5-2B for AI font generation.
/// Downloads and caches the model from HuggingFace, runs inference entirely on-device
/// using Apple's MLX framework (Metal-accelerated).
///
/// When MLX is not available (e.g. simulator builds), all methods gracefully degrade
/// and report the model as unavailable.
@Observable
@MainActor
final class LocalLLMService {

    // MARK: - State

    enum ModelState: Equatable {
        case idle
        case unavailable
        case downloading(progress: Double)
        case loading
        case ready
        case generating(progress: String)
        case error(String)

        static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.unavailable, .unavailable),
                 (.loading, .loading), (.ready, .ready): return true
            case (.downloading(let a), .downloading(let b)): return a == b
            case (.generating(let a), .generating(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    var state: ModelState = .idle
    var lastOutput: String = ""

    #if canImport(MLX)
    private var modelContainer: ModelContainer?
    #endif

    static let modelID = "mlx-community/Qwen3.5-2B-bf16"

    static var isMLXAvailable: Bool {
        #if canImport(MLX)
        return true
        #else
        return false
        #endif
    }

    init() {
        #if !canImport(MLX)
        state = .unavailable
        #endif
    }

    // MARK: - Model Lifecycle

    /// Downloads (if needed) and loads the Qwen3.5-2B model into memory.
    func loadModel() async {
        #if canImport(MLX)
        guard state == .idle || state.isError else { return }
        state = .downloading(progress: 0)

        do {
            let modelConfig = ModelConfiguration(id: Self.modelID) {
                progress in
                Task { @MainActor in
                    self.state = .downloading(progress: progress.fractionCompleted)
                }
            }

            state = .loading
            modelContainer = try await MLXLLM.loadModelContainer(configuration: modelConfig)
            state = .ready
        } catch {
            state = .error("Failed to load model: \(error.localizedDescription)")
        }
        #else
        state = .unavailable
        #endif
    }

    /// Unloads the model to free memory.
    func unloadModel() {
        #if canImport(MLX)
        modelContainer = nil
        #endif
        state = .idle
        lastOutput = ""
    }

    var isReady: Bool {
        state == .ready
    }

    // MARK: - Generation

    /// Generates SVG path data for a single glyph character based on a style description.
    func generateGlyphSVG(
        character: String,
        style: String,
        temperature: Float = 0.7,
        maxTokens: Int = 512
    ) async throws -> String {
        #if canImport(MLX)
        guard let container = modelContainer else {
            throw LLMError.modelNotLoaded
        }

        let prompt = buildGlyphPrompt(character: character, style: style)
        state = .generating(progress: "Generating '\(character)'...")

        let result = try await container.perform { context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
            var output = ""
            let params = GenerateParameters(temperature: temperature)

            for try await token in try MLXLMCommon.generate(
                input: input,
                parameters: params,
                context: context
            ) {
                if output.count > maxTokens * 4 { break }
                output += token.output
                if output.contains("</svg>") { break }
            }

            return output
        }

        lastOutput = result
        state = .ready
        return result
        #else
        throw LLMError.mlxNotAvailable
        #endif
    }

    /// Generates SVG paths for multiple glyphs in batch with a consistent style.
    func generateBatchGlyphs(
        characters: [String],
        style: String,
        temperature: Float = 0.7,
        onProgress: @escaping (String, Int, Int) -> Void
    ) async throws -> [String: String] {
        #if canImport(MLX)
        var results: [String: String] = [:]

        for (index, char) in characters.enumerated() {
            state = .generating(progress: "Generating '\(char)' (\(index + 1)/\(characters.count))...")
            onProgress(char, index + 1, characters.count)

            let svg = try await generateGlyphSVG(
                character: char,
                style: style,
                temperature: temperature
            )
            results[char] = svg
        }

        state = .ready
        return results
        #else
        throw LLMError.mlxNotAvailable
        #endif
    }

    /// Generates a font style description from a high-level prompt.
    func generateStyleDescription(from prompt: String) async throws -> String {
        #if canImport(MLX)
        guard let container = modelContainer else {
            throw LLMError.modelNotLoaded
        }

        let systemPrompt = """
        You are a typography expert. Given a user's description of a font style, \
        output a concise technical description of the font characteristics including: \
        stroke weight (thin/regular/bold/heavy), serif style (sans-serif/serif/slab-serif), \
        contrast (low/medium/high), roundness, slant angle, and any decorative features. \
        Be specific and concise. Output ONLY the technical description, nothing else.
        """

        let fullPrompt = "<|system|>\(systemPrompt)<|end|>\n<|user|>\(prompt)<|end|>\n<|assistant|>"
        state = .generating(progress: "Analyzing style...")

        let result = try await container.perform { context in
            let input = try await context.processor.prepare(input: .init(prompt: fullPrompt))
            var output = ""

            for try await token in try MLXLMCommon.generate(
                input: input,
                parameters: GenerateParameters(temperature: 0.5),
                context: context
            ) {
                output += token.output
                if output.count > 300 { break }
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        state = .ready
        return result
        #else
        throw LLMError.mlxNotAvailable
        #endif
    }

    // MARK: - Prompt Construction

    #if canImport(MLX)
    private func buildGlyphPrompt(character: String, style: String) -> String {
        """
        <|system|>You are a font designer AI. Generate an SVG path for a single \
        typographic glyph. Output ONLY a valid SVG element with a single <path> tag \
        using the 'd' attribute. The viewBox should be "0 0 512 512". The glyph \
        should be centered, well-proportioned, and match the requested style. \
        Use only M, L, Q, C, and Z path commands. Do not include any text or \
        explanation outside the SVG.<|end|>
        <|user|>Generate an SVG path for the character "\(character)" in this style: \(style). \
        The path should fill a 512x512 viewBox with proper typographic proportions \
        (baseline at y=400, cap-height at y=100, x-height at y=230).<|end|>
        <|assistant|><svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
        """
    }
    #endif

    // MARK: - Errors

    enum LLMError: Error, LocalizedError {
        case modelNotLoaded
        case generationFailed(String)
        case invalidSVGOutput
        case mlxNotAvailable

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "Model is not loaded. Please load the model first."
            case .generationFailed(let msg): return "Generation failed: \(msg)"
            case .invalidSVGOutput: return "The model produced invalid SVG output."
            case .mlxNotAvailable: return "MLX is not available on this platform. AI generation requires a device with Apple Silicon."
            }
        }
    }
}

// MARK: - ModelState Helpers

extension LocalLLMService.ModelState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .idle: return "Model not loaded"
        case .unavailable: return "MLX not available on this platform"
        case .downloading(let p): return "Downloading... \(Int(p * 100))%"
        case .loading: return "Loading model into memory..."
        case .ready: return "Ready"
        case .generating(let p): return p
        case .error(let e): return "Error: \(e)"
        }
    }

    var isWorking: Bool {
        switch self {
        case .downloading, .loading, .generating: return true
        default: return false
        }
    }
}
