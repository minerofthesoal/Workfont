# GlyphCrafter

A cutting-edge iOS application for creating custom hand-drawn fonts entirely on-device. Draw individual glyphs with touch or Apple Pencil, compile them into standard TrueType (`.ttf`) fonts, and type with your creations using the bundled Custom Keyboard Extension.

## Features

### Glyph Editor Canvas
- PencilKit-powered drawing interface with Apple Pencil and touch support
- Adjustable brush sizes (1-20pt) with pen, eraser, lasso select, and move tools
- Typography guide overlays (baseline, cap height, x-height, descender lines)
- Full character set: A-Z, a-z, 0-9, and 33 common symbols (95 glyphs total)
- Pinch-to-zoom canvas with undo/redo support
- Per-glyph metrics: width, bearings, and advance width

### Font Compiler & TTF Exporter
- On-device TrueType font compilation with proper table structure
- Generates valid `.ttf` files with 10 standard TTF tables (head, hhea, maxp, OS/2, name, cmap, glyf, loca, hmtx, post)
- Quadratic B-spline path smoothing for clean outlines
- Configuration Profile (`.mobileconfig`) export for one-tap system font installation
- Sticker Pack export (PNG images) for messaging apps
- Share via AirDrop, email, or Files app

### Custom Keyboard Extension
- Full QWERTY keyboard layout with shift and symbol modes
- Reads custom glyph data from the shared App Group container
- Visual indicators on keys that have custom glyphs
- Globe key for switching between keyboards
- Lightweight design optimized for keyboard extension memory limits

### Font Management
- Create, duplicate, rename, and delete font projects
- Per-category completion tracking (uppercase, lowercase, digits, symbols)
- Live font preview with customizable sample text and font size
- Font settings editor (family name, style, metrics: UPM, ascender, descender)

## Requirements

- iOS 26.0+
- Xcode 16.0+
- Swift 6.0+
- Apple Developer account (for keyboard extension provisioning)

## Project Structure

```
GlyphCrafter/
├── App/
│   ├── GlyphCrafterApp.swift          # App entry point
│   └── ContentView.swift              # Tab-based navigation
├── Models/
│   ├── GlyphProject.swift             # Glyph, FontProject, enums
│   └── FontProjectStore.swift         # Observable state management
├── Views/
│   ├── FontList/
│   │   └── FontProjectListView.swift  # Project list with search
│   ├── Editor/
│   │   ├── GlyphGridView.swift        # Character grid selector
│   │   ├── GlyphEditorView.swift      # Full-screen drawing editor
│   │   ├── DrawingCanvasView.swift     # PencilKit UIViewRepresentable
│   │   └── FontSettingsView.swift     # Font metadata editor
│   ├── Preview/
│   │   └── FontPreviewView.swift      # Live text rendering preview
│   └── Export/
│       └── ExportView.swift           # Export format selection & sharing
├── Services/
│   ├── TTFCompiler.swift              # TrueType binary compiler (actor)
│   └── FontExportService.swift        # Export orchestration
├── Extensions/
│   └── PathConversion.swift           # PKDrawing -> CGPath -> TTF points
├── Resources/
├── Assets.xcassets/
├── Info.plist
└── GlyphCrafter.entitlements

GlyphCrafterKeyboard/
├── KeyboardViewController.swift       # Custom keyboard extension
├── Info.plist
└── GlyphCrafterKeyboard.entitlements

Scripts/
└── generate_app_icon.py               # App icon generator (SVG/PNG)

Tests/
└── GlyphCrafterTests/
    ├── GlyphProjectTests.swift        # Model & category tests
    └── TTFCompilerTests.swift         # TTF binary format tests

.github/
└── workflows/
    └── build.yml                      # CI/CD pipeline
```

## Setup

1. Clone the repository
2. Open `GlyphCrafter.xcodeproj` in Xcode 16+
3. Set your Development Team in Signing & Capabilities for both targets
4. Configure the App Group identifier (`group.com.glyphcrafter.app`) in both targets
5. Build and run on a device or simulator

### Keyboard Extension Setup

1. Build and run the app on a device
2. Go to **Settings > General > Keyboard > Keyboards > Add New Keyboard**
3. Select **GlyphCrafter Keyboard**
4. Enable **Allow Full Access** (required for reading font data from shared container)

## Generating the App Icon

```bash
# Generate PNG (requires Pillow)
pip install Pillow
python3 Scripts/generate_app_icon.py

# Or output SVG to stdout
python3 Scripts/generate_app_icon.py --svg
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build.yml`) provides:

| Job | Trigger | Description |
|-----|---------|-------------|
| **Lint** | Push/PR | SwiftLint analysis + project structure verification |
| **Build** | Push/PR | Debug & Release builds (matrix strategy) |
| **Test** | Push/PR | Unit tests with result artifacts |
| **Icon** | Push/PR | Python-based app icon generation |
| **Archive** | Tags (`v*`) | Xcode archive for distribution |
| **Release** | Tags (`v*`) | GitHub Release with artifacts |

## Architecture

- **SwiftUI** with the `@Observable` macro (Observation framework)
- **Swift 6 concurrency** with actor-based TTF compilation
- **PencilKit** for high-fidelity drawing with Apple Pencil
- **App Groups** for shared data between main app and keyboard extension
- JSON-based persistence via `Codable` with atomic writes

## License

See [LICENSE](LICENSE) for details.
