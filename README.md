# GlyphCrafter

A cutting-edge iOS application for creating custom hand-drawn fonts entirely on-device. Draw individual glyphs with touch or Apple Pencil, use AI to generate entire font styles with an on-device LLM, compile them into standard TrueType (`.ttf`) fonts, and type with your creations using the bundled Custom Keyboard Extension.

## Features

### Glyph Editor Canvas
- PencilKit-powered drawing interface with Apple Pencil and touch support
- Adjustable brush sizes (1-20pt) with pen, eraser, lasso select, and monoline tools
- Typography guide overlays (ascender, cap height, x-height, baseline, descender) with labels at zoom
- Full character set: A-Z, a-z, 0-9, and 33 common symbols (95 glyphs total)
- Pinch-to-zoom (up to 4x) with pan support, double-tap to reset
- Proper undo/redo via UndoManager integration
- Context menu on glyph cells to clear drawings
- Grid snap toggle for precise alignment

### AI Font Generator (On-Device LLM)
- **Qwen3.5-2B** running locally via [MLX Swift](https://github.com/ml-explore/mlx-swift) (Metal-accelerated, no server needed)
- Model downloaded from `mlx-community/Qwen3.5-2B-bf16` on HuggingFace
- 8 style presets: Handwritten, Serif, Sans-Serif, Monospace, Brush, Pixel, Gothic, Rounded
- Free-form style descriptions with adjustable creativity (temperature) slider
- Batch generation scopes: Sample (5 chars), A-Z, a-z, 0-9, or Full Set (62 chars)
- SVG path output parsed and converted to PencilKit drawings automatically
- Apply AI glyphs to any project (overwrite or skip existing)
- Full SVG path parser supporting M, L, H, V, Q, C, Z commands (absolute + relative)

### Font Compiler & TTF Exporter
- On-device TrueType font compilation with proper table structure
- Generates valid `.ttf` files with 10 standard TTF tables (head, hhea, maxp, OS/2, name, cmap, glyf, loca, hmtx, post)
- Quadratic B-spline path smoothing for clean outlines
- Configuration Profile (`.mobileconfig`) export for one-tap system font installation
- Sticker Pack export (PNG images) for messaging apps
- Share via AirDrop, email, or Files app

### Custom Keyboard Extension
- Full QWERTY keyboard layout with shift, caps lock (double-tap), and symbol modes
- Reads custom glyph data from shared App Group container
- **Rendered glyph previews on key caps** - keys with custom glyphs show the actual hand-drawn character
- Long-press delete for continuous backspace
- Font name displayed on space bar
- Key press animations
- Globe key for switching between keyboards

### Font Management
- Create, duplicate, rename, and delete font projects
- Per-category completion tracking (uppercase, lowercase, digits, symbols)
- Live font preview with customizable sample text and font size
- Font settings editor (family name, style, metrics: UPM, ascender, descender)

## Building

### Requirements
- iOS 18.0+
- Xcode 16.0+
- Swift 6.0+
- Apple Developer account (for keyboard extension provisioning)
- ~4GB free storage for Qwen3.5-2B model (downloaded on first AI use)

### Quick Start

```bash
# Build (no signing, for development)
make build

# Run tests
make test

# Build unsigned IPA (for CI or sideloading)
make ipa-unsigned

# Build signed IPA (requires provisioning profile)
make ipa

# Clean all build artifacts
make clean
```

### Xcode Setup

1. Open `GlyphCrafter.xcodeproj` in Xcode 16+
2. Set your Development Team in Signing & Capabilities for both targets
3. Configure the App Group identifier (`group.com.glyphcrafter.app`) in both targets
4. (Optional) For AI features: Add MLX Swift packages via File > Add Package Dependencies:
   - `https://github.com/ml-explore/mlx-swift` (0.21.0+) — add MLX, MLXRandom, MLXNN, MLXOptimizers
   - `https://github.com/ml-explore/mlx-swift-examples` (main branch) — add MLXLMCommon, MLXLLM
5. Build and run on a device or simulator

### Keyboard Extension Setup

1. Build and run the app on a device
2. Go to **Settings > General > Keyboard > Keyboards > Add New Keyboard**
3. Select **GlyphCrafter Keyboard**
4. Enable **Allow Full Access** (required for reading font data from shared container)

## Project Structure

```
GlyphCrafter/
├── App/
│   ├── GlyphCrafterApp.swift              # App entry + LLM service injection
│   └── ContentView.swift                  # 5-tab navigation (Projects/Editor/AI/Preview/Export)
├── Models/
│   ├── GlyphProject.swift                 # Glyph, FontProject, enums
│   └── FontProjectStore.swift             # Observable state management
├── Views/
│   ├── FontList/
│   │   └── FontProjectListView.swift      # Project list with search
│   ├── Editor/
│   │   ├── GlyphGridView.swift            # Character grid + context menus
│   │   ├── GlyphEditorView.swift          # Full-screen editor with undo/redo
│   │   ├── DrawingCanvasView.swift        # PencilKit UIViewRepresentable
│   │   └── FontSettingsView.swift         # Font metadata editor
│   ├── AI/
│   │   └── AIFontGeneratorView.swift      # AI generation UI + style presets
│   ├── Preview/
│   │   └── FontPreviewView.swift          # Live text rendering preview
│   └── Export/
│       └── ExportView.swift               # Export format selection & sharing
├── Services/
│   ├── TTFCompiler.swift                  # TrueType binary compiler (actor)
│   ├── FontExportService.swift            # Export orchestration
│   └── AI/
│       ├── LocalLLMService.swift          # MLX Swift Qwen3.5-2B integration
│       └── SVGToPathConverter.swift       # SVG path → PencilKit drawing
├── Extensions/
│   └── PathConversion.swift               # PKDrawing → CGPath → TTF points
├── Package.swift                          # SPM deps (MLX Swift, MLXLLM)
├── Assets.xcassets/
├── Info.plist
└── GlyphCrafter.entitlements

GlyphCrafterKeyboard/
├── KeyboardViewController.swift           # Keyboard with glyph-rendered key caps
├── Info.plist
└── GlyphCrafterKeyboard.entitlements

Scripts/
└── generate_app_icon.py                   # App icon generator (SVG/PNG)

Tests/
└── GlyphCrafterTests/
    ├── GlyphProjectTests.swift            # Model & category tests
    └── TTFCompilerTests.swift             # TTF binary format tests

ExportOptions.plist                        # IPA export configuration
Makefile                                   # Build/test/IPA commands
.github/workflows/build.yml               # CI/CD pipeline (8 jobs)
```

## IPA Output

The project supports multiple IPA generation paths:

| Method | Command | Signing | Use Case |
|--------|---------|---------|----------|
| `make ipa` | Makefile | Signed | Local dev with provisioning profile |
| `make ipa-unsigned` | Makefile | Unsigned | CI builds, sideloading via AltStore/TrollStore |
| CI `ipa` job | GitHub Actions | Unsigned | Every push (artifact download) |
| CI `archive` job | GitHub Actions | Signed | Release tags (`v*`) only |

Unsigned IPAs can be installed via:
- **AltStore** / **SideStore** for sideloading
- **TrollStore** on compatible iOS versions
- **Apple Configurator 2** for supervised devices
- Re-signing with `ldid` or `codesign` for jailbroken devices

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build.yml`) provides:

| Job | Trigger | Description |
|-----|---------|-------------|
| **Lint** | Push/PR | SwiftLint + project structure verification |
| **Resolve Deps** | Push/PR | SPM dependency resolution + caching |
| **Build** | Push/PR | Debug & Release builds (matrix) |
| **Test** | Push/PR | Unit tests with xcresult artifacts |
| **Icon** | Push/PR | Python app icon generation |
| **IPA** | Push/PR | Build unsigned `.ipa` artifact |
| **Archive** | Tags (`v*`) | Xcode archive + signed IPA export |
| **Release** | Tags (`v*`) | GitHub Release with IPA + icon |

## Architecture

- **SwiftUI** with the `@Observable` macro (Observation framework)
- **Swift 6 concurrency** with actor-based TTF compilation
- **PencilKit** for high-fidelity drawing with Apple Pencil
- **MLX Swift** for on-device LLM inference (Metal-accelerated)
- **App Groups** for shared data between main app and keyboard extension
- JSON-based persistence via `Codable` with atomic writes

## Generating the App Icon

```bash
# Generate PNG (requires Pillow)
pip install Pillow
python3 Scripts/generate_app_icon.py

# Or output SVG to stdout
python3 Scripts/generate_app_icon.py --svg
```

## License

See [LICENSE](LICENSE) for details.
