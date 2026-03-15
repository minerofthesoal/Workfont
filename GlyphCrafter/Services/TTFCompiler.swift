import Foundation
import CoreGraphics
import PencilKit
import UIKit

// MARK: - TrueType Font Compiler

/// Compiles hand-drawn glyph paths into a valid TrueType Font (.ttf) binary.
///
/// This compiler generates the required TTF tables:
/// - `head`: Font header with global metrics
/// - `hhea`: Horizontal header
/// - `maxp`: Maximum profile (number of glyphs)
/// - `OS/2`: OS/2 and Windows metrics
/// - `name`: Naming table (family, style, etc.)
/// - `cmap`: Character-to-glyph mapping
/// - `loca`: Glyph location offsets
/// - `glyf`: Glyph outline data
/// - `hmtx`: Horizontal metrics
/// - `post`: PostScript names
actor TTFCompiler {

    struct CompilationResult: Sendable {
        let data: Data
        let glyphCount: Int
        let fileName: String
    }

    enum CompilerError: Error, LocalizedError {
        case noGlyphs
        case invalidPath
        case encodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noGlyphs: return "No glyphs with drawings found."
            case .invalidPath: return "Invalid glyph path data."
            case .encodingFailed(let msg): return "Encoding failed: \(msg)"
            }
        }
    }

    // MARK: - Public API

    func compile(project: FontProject) throws -> CompilationResult {
        let drawnGlyphs = project.glyphs.filter(\.hasDrawing)
        // Always include .notdef and space even if not drawn
        let allGlyphs = prepareGlyphs(project: project, drawnGlyphs: drawnGlyphs)

        var builder = TTFBuilder(
            familyName: project.familyName,
            styleName: project.styleName,
            unitsPerEm: UInt16(project.unitsPerEm),
            ascender: Int16(project.ascender),
            descender: Int16(project.descender),
            lineGap: Int16(project.lineGap)
        )

        // Convert PKDrawing paths to TTF contours
        for glyph in allGlyphs {
            let contours = extractContours(from: glyph, unitsPerEm: project.unitsPerEm)
            let advance = UInt16(min(
                Int(glyph.advance * CGFloat(project.unitsPerEm) / 512.0),
                Int(UInt16.max)
            ))
            builder.addGlyph(
                unicode: glyph.unicodeScalar,
                contours: contours,
                advance: advance,
                lsb: Int16(glyph.bearingX * CGFloat(project.unitsPerEm) / 512.0)
            )
        }

        let data = try builder.build()
        return CompilationResult(
            data: data,
            glyphCount: allGlyphs.count,
            fileName: "\(project.familyName)-\(project.styleName).ttf"
        )
    }

    // MARK: - Glyph Preparation

    private func prepareGlyphs(project: FontProject, drawnGlyphs: [Glyph]) -> [Glyph] {
        var result: [Glyph] = []

        // .notdef glyph (required, glyph index 0)
        result.append(Glyph(
            character: "\0",
            unicodeScalar: 0,
            width: 512,
            height: 512,
            advance: CGFloat(project.unitsPerEm / 2)
        ))

        // Space glyph
        if !drawnGlyphs.contains(where: { $0.unicodeScalar == 0x20 }) {
            result.append(Glyph(
                character: " ",
                unicodeScalar: 0x20,
                width: 0,
                height: 0,
                advance: CGFloat(project.unitsPerEm / 4)
            ))
        }

        result.append(contentsOf: drawnGlyphs.sorted { $0.unicodeScalar < $1.unicodeScalar })
        return result
    }

    // MARK: - Contour Extraction

    private func extractContours(from glyph: Glyph, unitsPerEm: Int) -> [TTFContour] {
        guard !glyph.pathData.isEmpty,
              let drawing = try? PKDrawing(data: glyph.pathData)
        else { return [] }

        let scale = CGFloat(unitsPerEm) / 512.0
        var contours: [TTFContour] = []

        for stroke in drawing.strokes {
            var points: [TTFPoint] = []
            let path = stroke.path

            guard path.count >= 2 else { continue }

            for i in 0..<path.count {
                let location = path[i].location
                // TTF coordinate system: Y increases upward, origin at baseline
                let x = Int16(location.x * scale)
                let y = Int16((512.0 - location.y) * scale) // Flip Y axis
                points.append(TTFPoint(x: x, y: y, onCurve: true))
            }

            // Apply path smoothing: convert to quadratic B-spline control points
            let smoothed = smoothPath(points: points)
            contours.append(TTFContour(points: smoothed))
        }

        return contours
    }

    /// Applies quadratic B-spline smoothing to reduce jagged hand-drawn lines.
    private func smoothPath(points: [TTFPoint]) -> [TTFPoint] {
        guard points.count > 2 else { return points }

        var smoothed: [TTFPoint] = []
        smoothed.append(points[0]) // First point always on-curve

        var i = 1
        while i < points.count - 1 {
            // Insert an off-curve control point between every two on-curve points
            let prev = points[i - 1]
            let curr = points[i]
            let next = points[i + 1]

            // Control point (off-curve)
            smoothed.append(TTFPoint(x: curr.x, y: curr.y, onCurve: false))

            // Implied on-curve point (midpoint between control and next)
            if i + 1 < points.count - 1 {
                let midX = Int16((Int(curr.x) + Int(next.x)) / 2)
                let midY = Int16((Int(curr.y) + Int(next.y)) / 2)
                smoothed.append(TTFPoint(x: midX, y: midY, onCurve: true))
            }

            // Skip ahead based on density to reduce point count
            let dx = abs(Int(next.x) - Int(prev.x))
            let dy = abs(Int(next.y) - Int(prev.y))
            let distance = dx + dy
            i += distance < 20 ? 3 : 2
        }

        smoothed.append(points.last!) // Last point always on-curve
        return smoothed
    }
}

// MARK: - TTF Data Structures

struct TTFPoint: Sendable {
    let x: Int16
    let y: Int16
    let onCurve: Bool
}

struct TTFContour: Sendable {
    let points: [TTFPoint]
}

struct TTFGlyphData: Sendable {
    let unicode: UInt32
    let contours: [TTFContour]
    let advance: UInt16
    let lsb: Int16
}

// MARK: - TTF Binary Builder

struct TTFBuilder {
    let familyName: String
    let styleName: String
    let unitsPerEm: UInt16
    let ascender: Int16
    let descender: Int16
    let lineGap: Int16

    private var glyphs: [TTFGlyphData] = []

    init(familyName: String, styleName: String, unitsPerEm: UInt16, ascender: Int16, descender: Int16, lineGap: Int16) {
        self.familyName = familyName
        self.styleName = styleName
        self.unitsPerEm = unitsPerEm
        self.ascender = ascender
        self.descender = descender
        self.lineGap = lineGap
    }

    mutating func addGlyph(unicode: UInt32, contours: [TTFContour], advance: UInt16, lsb: Int16) {
        glyphs.append(TTFGlyphData(unicode: unicode, contours: contours, advance: advance, lsb: lsb))
    }

    func build() throws -> Data {
        let numTables: UInt16 = 10
        var data = Data()

        // Offset table
        data.appendUInt32(0x00010000) // sfVersion (TrueType)
        data.appendUInt16(numTables)
        let searchRange = UInt16(highestPowerOf2(Int(numTables)) * 16)
        data.appendUInt16(searchRange)
        data.appendUInt16(UInt16(log2(Double(highestPowerOf2(Int(numTables))))))
        data.appendUInt16(numTables * 16 - searchRange)

        // Build all tables
        let headTable = buildHeadTable()
        let hheaTable = buildHheaTable()
        let maxpTable = buildMaxpTable()
        let os2Table = buildOS2Table()
        let nameTable = buildNameTable()
        let cmapTable = buildCmapTable()
        let (glyfTable, locaOffsets) = buildGlyfTable()
        let locaTable = buildLocaTable(offsets: locaOffsets)
        let hmtxTable = buildHmtxTable()
        let postTable = buildPostTable()

        let tables: [(tag: String, data: Data)] = [
            ("cmap", cmapTable),
            ("glyf", glyfTable),
            ("head", headTable),
            ("hhea", hheaTable),
            ("hmtx", hmtxTable),
            ("loca", locaTable),
            ("maxp", maxpTable),
            ("name", nameTable),
            ("OS/2", os2Table),
            ("post", postTable),
        ]

        // Calculate table directory offsets
        let headerSize = 12 + Int(numTables) * 16
        var currentOffset = headerSize

        // Write table directory
        for table in tables {
            // Tag (4 bytes)
            let tagBytes = Array(table.tag.utf8)
            for i in 0..<4 {
                data.append(i < tagBytes.count ? tagBytes[i] : 0x20)
            }
            // Checksum
            data.appendUInt32(calculateChecksum(table.data))
            // Offset
            data.appendUInt32(UInt32(currentOffset))
            // Length
            data.appendUInt32(UInt32(table.data.count))

            currentOffset += table.data.count
            // Pad to 4-byte boundary
            let padding = (4 - (table.data.count % 4)) % 4
            currentOffset += padding
        }

        // Write table data
        for table in tables {
            data.append(table.data)
            // Pad to 4-byte boundary
            let padding = (4 - (table.data.count % 4)) % 4
            for _ in 0..<padding {
                data.append(0)
            }
        }

        return data
    }

    // MARK: - Table Builders

    private func buildHeadTable() -> Data {
        var d = Data()
        d.appendUInt32(0x00010000)  // version
        d.appendUInt32(0x00005000)  // fontRevision
        d.appendUInt32(0)           // checksumAdjustment (filled later)
        d.appendUInt32(0x5F0F3CF5) // magicNumber
        d.appendUInt16(0x000B)      // flags
        d.appendUInt16(unitsPerEm)
        d.appendInt64(0)            // created (LONGDATETIME)
        d.appendInt64(0)            // modified
        d.appendInt16(0)            // xMin
        d.appendInt16(descender)    // yMin
        d.appendInt16(Int16(unitsPerEm)) // xMax
        d.appendInt16(ascender)     // yMax
        d.appendUInt16(0)           // macStyle
        d.appendUInt16(8)           // lowestRecPPEM
        d.appendInt16(2)            // fontDirectionHint
        d.appendInt16(1)            // indexToLocFormat (long)
        d.appendInt16(0)            // glyphDataFormat
        return d
    }

    private func buildHheaTable() -> Data {
        var d = Data()
        d.appendUInt32(0x00010000)  // version
        d.appendInt16(ascender)
        d.appendInt16(descender)
        d.appendInt16(lineGap)
        d.appendUInt16(unitsPerEm)  // advanceWidthMax
        d.appendInt16(0)            // minLeftSideBearing
        d.appendInt16(0)            // minRightSideBearing
        d.appendInt16(Int16(unitsPerEm)) // xMaxExtent
        d.appendInt16(1)            // caretSlopeRise
        d.appendInt16(0)            // caretSlopeRun
        d.appendInt16(0)            // caretOffset
        d.appendInt16(0)            // reserved
        d.appendInt16(0)            // reserved
        d.appendInt16(0)            // reserved
        d.appendInt16(0)            // reserved
        d.appendInt16(0)            // metricDataFormat
        d.appendUInt16(UInt16(glyphs.count)) // numHMetrics
        return d
    }

    private func buildMaxpTable() -> Data {
        var d = Data()
        d.appendUInt32(0x00010000)  // version
        d.appendUInt16(UInt16(glyphs.count))
        d.appendUInt16(1024)        // maxPoints
        d.appendUInt16(64)          // maxContours
        d.appendUInt16(0)           // maxCompositePoints
        d.appendUInt16(0)           // maxCompositeContours
        d.appendUInt16(1)           // maxZones
        d.appendUInt16(0)           // maxTwilightPoints
        d.appendUInt16(0)           // maxStorage
        d.appendUInt16(0)           // maxFunctionDefs
        d.appendUInt16(0)           // maxInstructionDefs
        d.appendUInt16(0)           // maxStackElements
        d.appendUInt16(0)           // maxSizeOfInstructions
        d.appendUInt16(0)           // maxComponentElements
        d.appendUInt16(0)           // maxComponentDepth
        return d
    }

    private func buildOS2Table() -> Data {
        var d = Data()
        d.appendUInt16(4)           // version
        d.appendInt16(Int16(unitsPerEm / 2)) // xAvgCharWidth
        d.appendUInt16(400)         // usWeightClass (Normal)
        d.appendUInt16(5)           // usWidthClass (Medium)
        d.appendUInt16(0)           // fsType
        d.appendInt16(Int16(unitsPerEm / 10)) // ySubscriptXSize
        d.appendInt16(Int16(unitsPerEm / 10)) // ySubscriptYSize
        d.appendInt16(0)            // ySubscriptXOffset
        d.appendInt16(Int16(unitsPerEm / 5)) // ySubscriptYOffset
        d.appendInt16(Int16(unitsPerEm / 10)) // ySuperscriptXSize
        d.appendInt16(Int16(unitsPerEm / 10)) // ySuperscriptYSize
        d.appendInt16(0)            // ySuperscriptXOffset
        d.appendInt16(Int16(unitsPerEm / 3)) // ySuperscriptYOffset
        d.appendInt16(Int16(unitsPerEm / 20)) // yStrikeoutSize
        d.appendInt16(Int16(unitsPerEm / 3))  // yStrikeoutPosition
        d.appendInt16(0)            // sFamilyClass

        // PANOSE (10 bytes)
        for _ in 0..<10 { d.append(0) }

        // ulUnicodeRange (16 bytes) - Basic Latin
        d.appendUInt32(0x00000001)
        d.appendUInt32(0)
        d.appendUInt32(0)
        d.appendUInt32(0)

        // achVendID (4 bytes)
        d.append(contentsOf: Array("GCFT".utf8))

        d.appendUInt16(0x0040)      // fsSelection (Regular)
        d.appendUInt16(0x0020)      // usFirstCharIndex (space)
        d.appendUInt16(0x007E)      // usLastCharIndex (~)
        d.appendInt16(ascender)     // sTypoAscender
        d.appendInt16(descender)    // sTypoDescender
        d.appendInt16(lineGap)      // sTypoLineGap
        d.appendUInt16(UInt16(ascender))  // usWinAscent
        d.appendUInt16(UInt16(abs(Int(descender)))) // usWinDescent
        d.appendUInt32(0x00000001)  // ulCodePageRange1
        d.appendUInt32(0)           // ulCodePageRange2
        d.appendInt16(Int16(Double(ascender) * 0.75)) // sxHeight
        d.appendInt16(ascender)     // sCapHeight
        d.appendUInt16(0)           // usDefaultChar
        d.appendUInt16(0x0020)      // usBreakChar
        d.appendUInt16(1)           // usMaxContext
        return d
    }

    private func buildNameTable() -> Data {
        let names: [(UInt16, String)] = [
            (0, "Copyright 2024 GlyphCrafter User"),
            (1, familyName),
            (2, styleName),
            (3, "\(familyName)-\(styleName)"),
            (4, "\(familyName) \(styleName)"),
            (5, "Version 1.0"),
            (6, "\(familyName)-\(styleName)"),
            (9, "GlyphCrafter User"),
            (11, "Created with GlyphCrafter"),
        ]

        var stringData = Data()
        var records = Data()
        var offset: UInt16 = 0

        for (nameID, value) in names {
            let encoded = Array(value.utf16)
            let length = UInt16(encoded.count * 2)

            // Platform 3 (Windows), Encoding 1 (Unicode BMP), Language 0x0409 (English)
            records.appendUInt16(3)       // platformID
            records.appendUInt16(1)       // encodingID
            records.appendUInt16(0x0409)  // languageID
            records.appendUInt16(nameID)
            records.appendUInt16(length)
            records.appendUInt16(offset)

            for scalar in encoded {
                stringData.appendUInt16(scalar)
            }
            offset += length
        }

        var d = Data()
        d.appendUInt16(0)                              // format
        d.appendUInt16(UInt16(names.count))            // count
        d.appendUInt16(UInt16(6 + records.count))      // stringOffset
        d.append(records)
        d.append(stringData)
        return d
    }

    private func buildCmapTable() -> Data {
        // Format 4 cmap subtable for BMP characters
        let unicodeGlyphs = glyphs.enumerated()
            .filter { $0.element.unicode > 0 && $0.element.unicode <= 0xFFFF }
            .sorted { $0.element.unicode < $1.element.unicode }

        // Build segments
        var segments: [(startCode: UInt16, endCode: UInt16, idDelta: Int16, idRangeOffset: UInt16)] = []

        var i = 0
        while i < unicodeGlyphs.count {
            let start = unicodeGlyphs[i]
            var end = start
            var isConsecutive = true

            // Find consecutive runs
            while i + 1 < unicodeGlyphs.count {
                let next = unicodeGlyphs[i + 1]
                if next.element.unicode == end.element.unicode + 1 &&
                   next.offset == end.offset + 1 {
                    end = next
                    i += 1
                } else {
                    break
                }
            }

            let startCode = UInt16(start.element.unicode)
            let endCode = UInt16(end.element.unicode)
            let idDelta = Int16(start.offset) - Int16(startCode)

            segments.append((startCode, endCode, idDelta, 0))
            i += 1
        }

        // Add sentinel segment
        segments.append((0xFFFF, 0xFFFF, 1, 0))

        let segCount = UInt16(segments.count)
        let searchRange = UInt16(highestPowerOf2(Int(segCount)) * 2)
        let entrySelector = UInt16(log2(Double(highestPowerOf2(Int(segCount)))))
        let rangeShift = segCount * 2 - searchRange

        var subtable = Data()
        subtable.appendUInt16(4)            // format
        let subtableLength = 14 + segments.count * 8
        subtable.appendUInt16(UInt16(subtableLength)) // length
        subtable.appendUInt16(0)            // language
        subtable.appendUInt16(segCount * 2)
        subtable.appendUInt16(searchRange)
        subtable.appendUInt16(entrySelector)
        subtable.appendUInt16(rangeShift)

        // endCode array
        for seg in segments { subtable.appendUInt16(seg.endCode) }
        subtable.appendUInt16(0) // reservedPad
        // startCode array
        for seg in segments { subtable.appendUInt16(seg.startCode) }
        // idDelta array
        for seg in segments { subtable.appendInt16(seg.idDelta) }
        // idRangeOffset array
        for seg in segments { subtable.appendUInt16(seg.idRangeOffset) }

        // Build cmap header
        var d = Data()
        d.appendUInt16(0)   // version
        d.appendUInt16(1)   // numTables

        // Encoding record: Platform 3, Encoding 1 (Windows Unicode BMP)
        d.appendUInt16(3)   // platformID
        d.appendUInt16(1)   // encodingID
        d.appendUInt32(UInt32(d.count + 4 + subtable.count - subtable.count)) // offset to subtable
        // Actually, offset is from start of cmap table
        // header = 4 bytes, + 1 record = 8 bytes = 12 bytes total header
        // So subtable starts at offset 12
        // Fix the offset:
        let headerSize = 4 + 8  // version(2) + numTables(2) + record(8)
        d.removeLast(4)
        d.appendUInt32(UInt32(headerSize))

        d.append(subtable)
        return d
    }

    private func buildGlyfTable() -> (Data, [UInt32]) {
        var d = Data()
        var offsets: [UInt32] = []

        for glyph in glyphs {
            offsets.append(UInt32(d.count))

            if glyph.contours.isEmpty {
                // Empty glyph (e.g., space, .notdef)
                // Write a minimal empty glyph header
                continue
            }

            let allPoints = glyph.contours.flatMap(\.points)
            let xMin = allPoints.map(\.x).min() ?? 0
            let yMin = allPoints.map(\.y).min() ?? 0
            let xMax = allPoints.map(\.x).max() ?? 0
            let yMax = allPoints.map(\.y).max() ?? 0

            // Glyph header
            d.appendInt16(Int16(glyph.contours.count)) // numberOfContours
            d.appendInt16(xMin)
            d.appendInt16(yMin)
            d.appendInt16(xMax)
            d.appendInt16(yMax)

            // End points of each contour
            var endPoint: UInt16 = 0
            for contour in glyph.contours {
                endPoint += UInt16(contour.points.count)
                d.appendUInt16(endPoint - 1)
            }

            // Instructions (none)
            d.appendUInt16(0)

            // Flags
            for contour in glyph.contours {
                for point in contour.points {
                    var flag: UInt8 = 0
                    if point.onCurve { flag |= 0x01 }
                    d.append(flag)
                }
            }

            // X coordinates (as deltas)
            var lastX: Int16 = 0
            for contour in glyph.contours {
                for point in contour.points {
                    let dx = point.x - lastX
                    d.appendInt16(dx)
                    lastX = point.x
                }
            }

            // Y coordinates (as deltas)
            var lastY: Int16 = 0
            for contour in glyph.contours {
                for point in contour.points {
                    let dy = point.y - lastY
                    d.appendInt16(dy)
                    lastY = point.y
                }
            }

            // Pad to 2-byte boundary
            if d.count % 2 != 0 { d.append(0) }
        }

        // Final offset (points to end of glyf table)
        offsets.append(UInt32(d.count))

        return (d, offsets)
    }

    private func buildLocaTable(offsets: [UInt32]) -> Data {
        var d = Data()
        for offset in offsets {
            d.appendUInt32(offset)  // long format (indexToLocFormat = 1)
        }
        return d
    }

    private func buildHmtxTable() -> Data {
        var d = Data()
        for glyph in glyphs {
            d.appendUInt16(glyph.advance)
            d.appendInt16(glyph.lsb)
        }
        return d
    }

    private func buildPostTable() -> Data {
        var d = Data()
        d.appendUInt32(0x00030000)  // format 3.0 (no glyph names)
        d.appendUInt32(0)           // italicAngle
        d.appendInt16(-100)         // underlinePosition
        d.appendInt16(50)           // underlineThickness
        d.appendUInt32(0)           // isFixedPitch
        d.appendUInt32(0)           // minMemType42
        d.appendUInt32(0)           // maxMemType42
        d.appendUInt32(0)           // minMemType1
        d.appendUInt32(0)           // maxMemType1
        return d
    }

    // MARK: - Utilities

    private func highestPowerOf2(_ n: Int) -> Int {
        var p = 1
        while p * 2 <= n { p *= 2 }
        return p
    }

    private func calculateChecksum(_ data: Data) -> UInt32 {
        var sum: UInt32 = 0
        var padded = data
        while padded.count % 4 != 0 { padded.append(0) }

        for i in stride(from: 0, to: padded.count, by: 4) {
            let value = UInt32(padded[i]) << 24 |
                        UInt32(padded[i+1]) << 16 |
                        UInt32(padded[i+2]) << 8 |
                        UInt32(padded[i+3])
            sum = sum &+ value
        }
        return sum
    }
}

// MARK: - Data Extension for Binary Writing

extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var big = value.bigEndian
        append(contentsOf: withUnsafeBytes(of: &big) { Array($0) })
    }

    mutating func appendInt16(_ value: Int16) {
        var big = value.bigEndian
        append(contentsOf: withUnsafeBytes(of: &big) { Array($0) })
    }

    mutating func appendUInt32(_ value: UInt32) {
        var big = value.bigEndian
        append(contentsOf: withUnsafeBytes(of: &big) { Array($0) })
    }

    mutating func appendInt64(_ value: Int64) {
        var big = value.bigEndian
        append(contentsOf: withUnsafeBytes(of: &big) { Array($0) })
    }
}
