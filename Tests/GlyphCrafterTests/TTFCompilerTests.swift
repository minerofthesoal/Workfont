import XCTest
@testable import GlyphCrafter

final class TTFCompilerTests: XCTestCase {

    // MARK: - Data Extension Tests

    func testAppendUInt16() {
        var data = Data()
        data.appendUInt16(0x0102)
        XCTAssertEqual(data, Data([0x01, 0x02]))
    }

    func testAppendInt16() {
        var data = Data()
        data.appendInt16(-1)
        // -1 in big-endian Int16 = 0xFF, 0xFF
        XCTAssertEqual(data, Data([0xFF, 0xFF]))
    }

    func testAppendUInt32() {
        var data = Data()
        data.appendUInt32(0x01020304)
        XCTAssertEqual(data, Data([0x01, 0x02, 0x03, 0x04]))
    }

    func testAppendInt64() {
        var data = Data()
        data.appendInt64(0)
        XCTAssertEqual(data.count, 8)
        XCTAssertEqual(data, Data(repeating: 0, count: 8))
    }

    // MARK: - TTF Structure Tests

    func testTTFPointCreation() {
        let point = TTFPoint(x: 100, y: 200, onCurve: true)
        XCTAssertEqual(point.x, 100)
        XCTAssertEqual(point.y, 200)
        XCTAssertTrue(point.onCurve)
    }

    func testTTFContourCreation() {
        let points = [
            TTFPoint(x: 0, y: 0, onCurve: true),
            TTFPoint(x: 100, y: 200, onCurve: false),
            TTFPoint(x: 200, y: 0, onCurve: true),
        ]
        let contour = TTFContour(points: points)
        XCTAssertEqual(contour.points.count, 3)
    }

    // MARK: - Compilation Tests

    func testCompileEmptyProjectProducesValidTTF() async throws {
        let project = FontProject(name: "Test", familyName: "Test")
        let compiler = TTFCompiler()

        // Even with no drawn glyphs, should produce a valid TTF
        // with at least .notdef and space glyphs
        let result = try await compiler.compile(project: project)

        // TTF magic: starts with 0x00010000
        XCTAssertGreaterThan(result.data.count, 12)
        let sfVersion = result.data.prefix(4)
        XCTAssertEqual(sfVersion, Data([0x00, 0x01, 0x00, 0x00]))
    }

    func testCompileResultFileName() async throws {
        let project = FontProject(name: "MyFont", familyName: "MyFamily", styleName: "Bold")
        let compiler = TTFCompiler()
        let result = try await compiler.compile(project: project)

        XCTAssertEqual(result.fileName, "MyFamily-Bold.ttf")
    }

    func testCompiledFontHasCorrectTableCount() async throws {
        let project = FontProject(name: "Test", familyName: "Test")
        let compiler = TTFCompiler()
        let result = try await compiler.compile(project: project)

        // Read numTables (bytes 4-5, big-endian UInt16)
        let numTables = UInt16(result.data[4]) << 8 | UInt16(result.data[5])
        XCTAssertEqual(numTables, 10) // We write 10 tables
    }
}
