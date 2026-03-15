import Foundation
import SwiftUI

// MARK: - Glyph Model

/// Represents a single hand-drawn glyph (character) with its vector path data.
struct Glyph: Identifiable, Codable, Sendable {
    let id: UUID
    var character: String
    var unicodeScalar: UInt32
    var pathData: Data
    var width: CGFloat
    var height: CGFloat
    var bearingX: CGFloat
    var bearingY: CGFloat
    var advance: CGFloat
    var lastModified: Date

    init(
        id: UUID = UUID(),
        character: String,
        unicodeScalar: UInt32,
        pathData: Data = Data(),
        width: CGFloat = 512,
        height: CGFloat = 512,
        bearingX: CGFloat = 0,
        bearingY: CGFloat = 0,
        advance: CGFloat = 512,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.character = character
        self.unicodeScalar = unicodeScalar
        self.pathData = pathData
        self.width = width
        self.height = height
        self.bearingX = bearingX
        self.bearingY = bearingY
        self.advance = advance
        self.lastModified = lastModified
    }

    var hasDrawing: Bool {
        !pathData.isEmpty
    }
}

// MARK: - Font Project Model

/// A complete font project containing metadata and all glyph definitions.
struct FontProject: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var familyName: String
    var styleName: String
    var version: String
    var unitsPerEm: Int
    var ascender: Int
    var descender: Int
    var lineGap: Int
    var glyphs: [Glyph]
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Untitled Font",
        familyName: String = "Untitled",
        styleName: String = "Regular",
        version: String = "1.0",
        unitsPerEm: Int = 1024,
        ascender: Int = 800,
        descender: Int = -200,
        lineGap: Int = 0,
        glyphs: [Glyph]? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.familyName = familyName
        self.styleName = styleName
        self.version = version
        self.unitsPerEm = unitsPerEm
        self.ascender = ascender
        self.descender = descender
        self.lineGap = lineGap
        self.glyphs = glyphs ?? Self.defaultGlyphs()
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    var completionPercentage: Double {
        let drawn = glyphs.filter(\.hasDrawing).count
        return glyphs.isEmpty ? 0 : Double(drawn) / Double(glyphs.count)
    }

    static func defaultGlyphs() -> [Glyph] {
        var glyphs: [Glyph] = []

        // Uppercase A-Z
        for scalar in UInt32(0x41)...UInt32(0x5A) {
            let char = String(UnicodeScalar(scalar)!)
            glyphs.append(Glyph(character: char, unicodeScalar: scalar))
        }

        // Lowercase a-z
        for scalar in UInt32(0x61)...UInt32(0x7A) {
            let char = String(UnicodeScalar(scalar)!)
            glyphs.append(Glyph(character: char, unicodeScalar: scalar))
        }

        // Digits 0-9
        for scalar in UInt32(0x30)...UInt32(0x39) {
            let char = String(UnicodeScalar(scalar)!)
            glyphs.append(Glyph(character: char, unicodeScalar: scalar))
        }

        // Common punctuation and symbols
        let symbols: [(String, UInt32)] = [
            (" ", 0x20), ("!", 0x21), ("\"", 0x22), ("#", 0x23),
            ("$", 0x24), ("%", 0x25), ("&", 0x26), ("'", 0x27),
            ("(", 0x28), (")", 0x29), ("*", 0x2A), ("+", 0x2B),
            (",", 0x2C), ("-", 0x2D), (".", 0x2E), ("/", 0x2F),
            (":", 0x3A), (";", 0x3B), ("<", 0x3C), ("=", 0x3D),
            (">", 0x3E), ("?", 0x3F), ("@", 0x40), ("[", 0x5B),
            ("\\", 0x5C), ("]", 0x5D), ("^", 0x5E), ("_", 0x5F),
            ("`", 0x60), ("{", 0x7B), ("|", 0x7C), ("}", 0x7D),
            ("~", 0x7E),
        ]
        for (char, scalar) in symbols {
            glyphs.append(Glyph(character: char, unicodeScalar: scalar))
        }

        return glyphs
    }
}

// MARK: - Glyph Category

enum GlyphCategory: String, CaseIterable, Sendable {
    case uppercase = "A-Z"
    case lowercase = "a-z"
    case digits = "0-9"
    case symbols = "Symbols"

    func filter(_ glyphs: [Glyph]) -> [Glyph] {
        switch self {
        case .uppercase:
            return glyphs.filter { $0.unicodeScalar >= 0x41 && $0.unicodeScalar <= 0x5A }
        case .lowercase:
            return glyphs.filter { $0.unicodeScalar >= 0x61 && $0.unicodeScalar <= 0x7A }
        case .digits:
            return glyphs.filter { $0.unicodeScalar >= 0x30 && $0.unicodeScalar <= 0x39 }
        case .symbols:
            return glyphs.filter { g in
                (g.unicodeScalar >= 0x20 && g.unicodeScalar <= 0x2F) ||
                (g.unicodeScalar >= 0x3A && g.unicodeScalar <= 0x40) ||
                (g.unicodeScalar >= 0x5B && g.unicodeScalar <= 0x60) ||
                (g.unicodeScalar >= 0x7B && g.unicodeScalar <= 0x7E)
            }
        }
    }
}

// MARK: - Editor Tool

enum EditorTool: String, CaseIterable, Sendable {
    case pen = "Pen"
    case eraser = "Eraser"
    case select = "Select"
    case move = "Move"

    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .eraser: return "eraser"
        case .select: return "lasso"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Sendable {
    case ttf = "TrueType (.ttf)"
    case configProfile = "Config Profile (.mobileconfig)"
    case stickerPack = "Sticker Pack"
}
