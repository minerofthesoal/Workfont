import Foundation
import CoreGraphics
import PencilKit
import UIKit

// MARK: - SVG to PencilKit Path Converter

/// Parses SVG path data from LLM output and converts it to PencilKit drawings
/// that can be stored as glyph path data.
struct SVGToPathConverter {

    enum ConversionError: Error, LocalizedError {
        case noPathFound
        case invalidPathData
        case parsingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noPathFound: return "No SVG path element found in output."
            case .invalidPathData: return "The path data could not be parsed."
            case .parsingFailed(let msg): return "SVG parsing failed: \(msg)"
            }
        }
    }

    // MARK: - Public API

    /// Extracts SVG path data from LLM output and converts to PKDrawing data.
    static func convert(svgOutput: String) throws -> Data {
        let pathData = try extractPathData(from: svgOutput)
        let cgPath = try parseSVGPath(pathData)
        let drawing = convertToDrawing(cgPath: cgPath)
        return drawing.dataRepresentation()
    }

    /// Extracts SVG path and returns CGPath for preview rendering.
    static func convertToCGPath(svgOutput: String) throws -> CGPath {
        let pathData = try extractPathData(from: svgOutput)
        return try parseSVGPath(pathData)
    }

    // MARK: - SVG Path Extraction

    /// Pulls the `d="..."` attribute from an SVG `<path>` element.
    private static func extractPathData(from svg: String) throws -> String {
        // Match <path d="..."/> or <path d='...'/> patterns
        let patterns = [
            #"<path[^>]*\sd=["\']([^"\']+)["\']"#,
            #"d=["\']([^"\']+)["\']"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
               let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
               let range = Range(match.range(at: 1), in: svg) {
                return String(svg[range])
            }
        }

        throw ConversionError.noPathFound
    }

    // MARK: - SVG Path Parsing

    /// Parses SVG path `d` attribute into a CGPath.
    /// Supports: M/m, L/l, H/h, V/v, Q/q, C/c, Z/z commands.
    private static func parseSVGPath(_ d: String) throws -> CGPath {
        let path = CGMutablePath()
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var startX: CGFloat = 0
        var startY: CGFloat = 0

        let tokens = tokenize(d)
        var i = 0

        while i < tokens.count {
            let token = tokens[i]

            guard let command = token.first, token.count == 1, command.isLetter else {
                i += 1
                continue
            }

            let isRelative = command.isLowercase
            i += 1

            switch command.uppercased().first! {
            case "M":
                while i + 1 < tokens.count, let x = Double(tokens[i]), let y = Double(tokens[i + 1]) {
                    let px = isRelative ? currentX + CGFloat(x) : CGFloat(x)
                    let py = isRelative ? currentY + CGFloat(y) : CGFloat(y)
                    path.move(to: CGPoint(x: px, y: py))
                    currentX = px; currentY = py
                    startX = px; startY = py
                    i += 2
                }

            case "L":
                while i + 1 < tokens.count, let x = Double(tokens[i]), let y = Double(tokens[i + 1]) {
                    let px = isRelative ? currentX + CGFloat(x) : CGFloat(x)
                    let py = isRelative ? currentY + CGFloat(y) : CGFloat(y)
                    path.addLine(to: CGPoint(x: px, y: py))
                    currentX = px; currentY = py
                    i += 2
                }

            case "H":
                while i < tokens.count, let x = Double(tokens[i]) {
                    let px = isRelative ? currentX + CGFloat(x) : CGFloat(x)
                    path.addLine(to: CGPoint(x: px, y: currentY))
                    currentX = px
                    i += 1
                }

            case "V":
                while i < tokens.count, let y = Double(tokens[i]) {
                    let py = isRelative ? currentY + CGFloat(y) : CGFloat(y)
                    path.addLine(to: CGPoint(x: currentX, y: py))
                    currentY = py
                    i += 1
                }

            case "Q":
                while i + 3 < tokens.count,
                      let cx = Double(tokens[i]), let cy = Double(tokens[i + 1]),
                      let ex = Double(tokens[i + 2]), let ey = Double(tokens[i + 3]) {
                    let cpx = isRelative ? currentX + CGFloat(cx) : CGFloat(cx)
                    let cpy = isRelative ? currentY + CGFloat(cy) : CGFloat(cy)
                    let epx = isRelative ? currentX + CGFloat(ex) : CGFloat(ex)
                    let epy = isRelative ? currentY + CGFloat(ey) : CGFloat(ey)
                    path.addQuadCurve(to: CGPoint(x: epx, y: epy), control: CGPoint(x: cpx, y: cpy))
                    currentX = epx; currentY = epy
                    i += 4
                }

            case "C":
                while i + 5 < tokens.count,
                      let c1x = Double(tokens[i]), let c1y = Double(tokens[i + 1]),
                      let c2x = Double(tokens[i + 2]), let c2y = Double(tokens[i + 3]),
                      let ex = Double(tokens[i + 4]), let ey = Double(tokens[i + 5]) {
                    let cp1 = CGPoint(
                        x: isRelative ? currentX + CGFloat(c1x) : CGFloat(c1x),
                        y: isRelative ? currentY + CGFloat(c1y) : CGFloat(c1y)
                    )
                    let cp2 = CGPoint(
                        x: isRelative ? currentX + CGFloat(c2x) : CGFloat(c2x),
                        y: isRelative ? currentY + CGFloat(c2y) : CGFloat(c2y)
                    )
                    let end = CGPoint(
                        x: isRelative ? currentX + CGFloat(ex) : CGFloat(ex),
                        y: isRelative ? currentY + CGFloat(ey) : CGFloat(ey)
                    )
                    path.addCurve(to: end, control1: cp1, control2: cp2)
                    currentX = end.x; currentY = end.y
                    i += 6
                }

            case "Z":
                path.closeSubpath()
                currentX = startX; currentY = startY

            default:
                break
            }
        }

        if path.isEmpty {
            throw ConversionError.invalidPathData
        }

        return path
    }

    /// Tokenizes SVG path data into commands and numbers.
    private static func tokenize(_ d: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in d {
            if char.isLetter {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else if char == "," || char == " " || char == "\n" || char == "\t" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if char == "-" && !current.isEmpty && !current.hasSuffix("e") {
                tokens.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    // MARK: - CGPath to PKDrawing

    /// Converts a CGPath into a PKDrawing by stroking each subpath.
    private static func convertToDrawing(cgPath: CGPath, strokeWidth: CGFloat = 3.0) -> PKDrawing {
        var allPoints: [[CGPoint]] = []
        var currentSubpath: [CGPoint] = []

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                if !currentSubpath.isEmpty {
                    allPoints.append(currentSubpath)
                }
                currentSubpath = [element.points[0]]

            case .addLineToPoint:
                currentSubpath.append(element.points[0])

            case .addQuadCurveToPoint:
                // Flatten quadratic curve into line segments
                guard let last = currentSubpath.last else { break }
                let cp = element.points[0]
                let end = element.points[1]
                for t in stride(from: 0.1, through: 1.0, by: 0.1) {
                    let t2 = CGFloat(t)
                    let mt = 1 - t2
                    let x = mt * mt * last.x + 2 * mt * t2 * cp.x + t2 * t2 * end.x
                    let y = mt * mt * last.y + 2 * mt * t2 * cp.y + t2 * t2 * end.y
                    currentSubpath.append(CGPoint(x: x, y: y))
                }

            case .addCurveToPoint:
                guard let last = currentSubpath.last else { break }
                let cp1 = element.points[0]
                let cp2 = element.points[1]
                let end = element.points[2]
                for t in stride(from: 0.1, through: 1.0, by: 0.1) {
                    let t2 = CGFloat(t)
                    let mt = 1 - t2
                    let x = mt*mt*mt*last.x + 3*mt*mt*t2*cp1.x + 3*mt*t2*t2*cp2.x + t2*t2*t2*end.x
                    let y = mt*mt*mt*last.y + 3*mt*mt*t2*cp1.y + 3*mt*t2*t2*cp2.y + t2*t2*t2*end.y
                    currentSubpath.append(CGPoint(x: x, y: y))
                }

            case .closeSubpath:
                if let first = currentSubpath.first {
                    currentSubpath.append(first)
                }
                allPoints.append(currentSubpath)
                currentSubpath = []

            @unknown default:
                break
            }
        }

        if !currentSubpath.isEmpty {
            allPoints.append(currentSubpath)
        }

        // Build PKDrawing from strokes
        var strokes: [PKStroke] = []
        let ink = PKInk(.pen, color: .black)

        for points in allPoints where points.count >= 2 {
            var strokePoints: [PKStrokePoint] = []
            for (i, point) in points.enumerated() {
                let sp = PKStrokePoint(
                    location: point,
                    timeOffset: TimeInterval(i) * 0.01,
                    size: CGSize(width: strokeWidth, height: strokeWidth),
                    opacity: 1.0,
                    force: 0.5,
                    azimuth: 0,
                    altitude: .pi / 2
                )
                strokePoints.append(sp)
            }

            let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
            strokes.append(PKStroke(ink: ink, path: strokePath))
        }

        return PKDrawing(strokes: strokes)
    }
}
