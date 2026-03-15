import XCTest
@testable import GlyphCrafter

final class GlyphProjectTests: XCTestCase {

    // MARK: - FontProject Tests

    func testDefaultProjectCreation() {
        let project = FontProject()
        XCTAssertEqual(project.name, "Untitled Font")
        XCTAssertEqual(project.familyName, "Untitled")
        XCTAssertEqual(project.styleName, "Regular")
        XCTAssertEqual(project.unitsPerEm, 1024)
        XCTAssertEqual(project.ascender, 800)
        XCTAssertEqual(project.descender, -200)
    }

    func testDefaultGlyphSet() {
        let project = FontProject()
        // 26 uppercase + 26 lowercase + 10 digits + 33 symbols = 95
        XCTAssertEqual(project.glyphs.count, 95)
    }

    func testGlyphCategoryFiltering() {
        let project = FontProject()
        XCTAssertEqual(GlyphCategory.uppercase.filter(project.glyphs).count, 26)
        XCTAssertEqual(GlyphCategory.lowercase.filter(project.glyphs).count, 26)
        XCTAssertEqual(GlyphCategory.digits.filter(project.glyphs).count, 10)
        XCTAssertEqual(GlyphCategory.symbols.filter(project.glyphs).count, 33)
    }

    func testCompletionPercentage() {
        var project = FontProject()
        XCTAssertEqual(project.completionPercentage, 0.0)

        // Mark some glyphs as "drawn" by giving them path data
        for i in 0..<10 {
            project.glyphs[i].pathData = Data([0x01])
        }
        let expected = 10.0 / 95.0
        XCTAssertEqual(project.completionPercentage, expected, accuracy: 0.001)
    }

    func testProjectCodable() throws {
        let project = FontProject(name: "Test Font", familyName: "TestFamily")
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(FontProject.self, from: data)

        XCTAssertEqual(decoded.name, "Test Font")
        XCTAssertEqual(decoded.familyName, "TestFamily")
        XCTAssertEqual(decoded.glyphs.count, project.glyphs.count)
    }

    // MARK: - Glyph Tests

    func testGlyphCreation() {
        let glyph = Glyph(character: "A", unicodeScalar: 0x41)
        XCTAssertEqual(glyph.character, "A")
        XCTAssertEqual(glyph.unicodeScalar, 0x41)
        XCTAssertFalse(glyph.hasDrawing)
    }

    func testGlyphHasDrawing() {
        var glyph = Glyph(character: "A", unicodeScalar: 0x41)
        XCTAssertFalse(glyph.hasDrawing)

        glyph.pathData = Data([0x01, 0x02, 0x03])
        XCTAssertTrue(glyph.hasDrawing)
    }

    func testGlyphCodable() throws {
        let glyph = Glyph(
            character: "B",
            unicodeScalar: 0x42,
            pathData: Data([0xFF, 0xFE]),
            width: 300,
            advance: 350
        )
        let data = try JSONEncoder().encode(glyph)
        let decoded = try JSONDecoder().decode(Glyph.self, from: data)

        XCTAssertEqual(decoded.character, "B")
        XCTAssertEqual(decoded.unicodeScalar, 0x42)
        XCTAssertEqual(decoded.pathData, Data([0xFF, 0xFE]))
        XCTAssertEqual(decoded.width, 300)
        XCTAssertEqual(decoded.advance, 350)
    }

    // MARK: - EditorTool Tests

    func testEditorToolSystemImages() {
        XCTAssertEqual(EditorTool.pen.systemImage, "pencil.tip")
        XCTAssertEqual(EditorTool.eraser.systemImage, "eraser")
        XCTAssertEqual(EditorTool.select.systemImage, "lasso")
        XCTAssertEqual(EditorTool.move.systemImage, "arrow.up.and.down.and.arrow.left.and.right")
    }

    func testAllEditorToolsCovered() {
        XCTAssertEqual(EditorTool.allCases.count, 4)
    }
}
