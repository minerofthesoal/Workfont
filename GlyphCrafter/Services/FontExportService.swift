import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - Font Export Service

/// Handles exporting fonts in various formats and generating installation profiles.
@MainActor
final class FontExportService {
    private let compiler = TTFCompiler()
    private let fileManager = FileManager.default

    enum ExportError: Error, LocalizedError {
        case compilationFailed(String)
        case writeFailed
        case profileGenerationFailed

        var errorDescription: String? {
            switch self {
            case .compilationFailed(let msg): return "Compilation failed: \(msg)"
            case .writeFailed: return "Failed to write file to disk."
            case .profileGenerationFailed: return "Failed to generate configuration profile."
            }
        }
    }

    // MARK: - TTF Export

    func exportTTF(project: FontProject, to directory: URL) async throws -> URL {
        let result = try await compiler.compile(project: project)
        let fileURL = directory.appendingPathComponent(result.fileName)

        try result.data.write(to: fileURL)
        return fileURL
    }

    // MARK: - Configuration Profile Export

    /// Generates a .mobileconfig profile that installs the font system-wide.
    func exportConfigProfile(project: FontProject, to directory: URL) async throws -> URL {
        let ttfResult = try await compiler.compile(project: project)
        let base64Font = ttfResult.data.base64EncodedString(options: .lineLength76Characters)

        let profileUUID = UUID().uuidString
        let payloadUUID = UUID().uuidString

        let profileXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>Font</key>
                    <data>
                    \(base64Font)
                    </data>
                    <key>Name</key>
                    <string>\(project.familyName)-\(project.styleName).ttf</string>
                    <key>PayloadDescription</key>
                    <string>Installs the \(project.familyName) font.</string>
                    <key>PayloadDisplayName</key>
                    <string>\(project.familyName) \(project.styleName)</string>
                    <key>PayloadIdentifier</key>
                    <string>com.glyphcrafter.font.\(payloadUUID)</string>
                    <key>PayloadType</key>
                    <string>com.apple.font</string>
                    <key>PayloadUUID</key>
                    <string>\(payloadUUID)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>PayloadDescription</key>
            <string>Installs the \(project.familyName) custom font created with GlyphCrafter.</string>
            <key>PayloadDisplayName</key>
            <string>\(project.familyName) Font</string>
            <key>PayloadIdentifier</key>
            <string>com.glyphcrafter.profile.\(profileUUID)</string>
            <key>PayloadOrganization</key>
            <string>GlyphCrafter</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(profileUUID)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """

        let fileName = "\(project.familyName)-\(project.styleName).mobileconfig"
        let fileURL = directory.appendingPathComponent(fileName)
        try profileXML.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - Sticker Pack Export

    /// Renders each drawn glyph as a PNG sticker image.
    func exportStickerPack(project: FontProject, to directory: URL) async throws -> [URL] {
        let stickerDir = directory.appendingPathComponent("\(project.familyName)_Stickers")
        try fileManager.createDirectory(at: stickerDir, withIntermediateDirectories: true)

        var urls: [URL] = []
        let drawnGlyphs = project.glyphs.filter(\.hasDrawing)

        for glyph in drawnGlyphs {
            let image = renderGlyphImage(glyph: glyph, size: CGSize(width: 300, height: 300))
            if let pngData = image.pngData() {
                let fileName = "glyph_\(String(format: "%04X", glyph.unicodeScalar)).png"
                let url = stickerDir.appendingPathComponent(fileName)
                try pngData.write(to: url)
                urls.append(url)
            }
        }

        return urls
    }

    // MARK: - Glyph Rendering

    private func renderGlyphImage(glyph: Glyph, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            guard let drawing = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: PKDrawingWrapper.self, from: glyph.pathData
            ) else { return }

            context.setStrokeColor(UIColor.black.cgColor)
            let scaleX = size.width / 512
            let scaleY = size.height / 512

            for pathInfo in drawing.paths {
                let points = pathInfo.points
                guard !points.isEmpty else { continue }

                context.setLineWidth(pathInfo.lineWidth * scaleX)
                context.move(to: CGPoint(x: points[0].x * scaleX, y: points[0].y * scaleY))
                for i in 1..<points.count {
                    context.addLine(to: CGPoint(x: points[i].x * scaleX, y: points[i].y * scaleY))
                }
                context.strokePath()
            }
        }
    }
}

// MARK: - PKDrawing Wrapper (for non-PencilKit contexts)

import PencilKit

/// Lightweight wrapper to extract path data from PKDrawing for rendering.
final class PKDrawingWrapper: NSObject, NSSecureCoding {
    static var supportsSecureCoding = true

    struct PathInfo {
        let points: [CGPoint]
        let lineWidth: CGFloat
    }

    let paths: [PathInfo]

    init(paths: [PathInfo]) {
        self.paths = paths
    }

    required init?(coder: NSCoder) {
        self.paths = []
    }

    func encode(with coder: NSCoder) {}
}
