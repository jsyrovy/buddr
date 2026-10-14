import Testing

@testable import Buddr

struct PixelFontTests {
    private static let white = PixelColor(red: 255, green: 255, blue: 255)

    @Test(arguments: PixelFont.allGlyphs.map(\.character))
    func glyphIsValid(character: Character) throws {
        let rows = try #require(PixelFont.glyphs[character])
        #expect(rows.count == 7 || rows.count == 9)
        #expect(Set(rows.map(\.count)).count == 1)
        #expect(rows.allSatisfy { $0.allSatisfy { $0 == "#" || $0 == "." } })
        if rows.count == 9 {
            // Only glyphs reaching below the baseline have the descender rows.
            #expect(rows.suffix(2).contains { $0.contains("#") })
        }
    }

    @Test func everyGlyphIsPaddedToTheLineHeight() {
        #expect(PixelFont.glyph(for: "A").count == PixelFont.height)
        #expect(PixelFont.glyph(for: "g").count == PixelFont.height)
    }

    @Test func widthCountsTheGlyphsAndTheSpacingBetweenThem() {
        #expect(PixelFont.width(of: "") == 0)
        #expect(PixelFont.width(of: "i") == 1)
        #expect(PixelFont.width(of: "ab") == 5 + 1 + 5)
        #expect(PixelFont.width(of: "a b") == 5 + 1 + 3 + 1 + 5)
    }

    @Test func lowercaseMarksAreDrawnAboveTheXHeight() {
        #expect(PixelFont.glyph(for: "č").prefix(4) == [".#.#", "..#.", ".###", "#..."])
        #expect(PixelFont.glyph(for: "é").prefix(3) == ["...#.", "..#..", ".###."])
        #expect(PixelFont.glyph(for: "ů").prefix(3) == ["..##.", "..##.", "#...#"])
        // The rest of the letter stays as it is.
        #expect(PixelFont.glyph(for: "ř").dropFirst(2) == PixelFont.glyph(for: "r").dropFirst(2))
    }

    @Test func anIWithAMarkLosesItsDot() {
        #expect(PixelFont.glyph(for: "í").prefix(4) == [".#", "#.", "#.", "#."])
    }

    @Test func aCaronAfterAnAscenderBecomesAnApostrophe() {
        #expect(PixelFont.glyph(for: "ď").prefix(3) == ["....#.#", "....#.#", ".####.."])
        #expect(PixelFont.glyph(for: "ť").prefix(3) == [".#.#", ".#.#", "###."])
    }

    @Test func decomposedLettersGetTheirMarksToo() {
        #expect(PixelFont.glyph(for: "c\u{030C}") == PixelFont.glyph(for: "č"))
    }

    @Test func capitalsAndOtherMarksAreDrawnWithoutTheMark() {
        #expect(PixelFont.glyph(for: "Č") == PixelFont.glyph(for: "C"))
        #expect(PixelFont.glyph(for: "Ů") == PixelFont.glyph(for: "U"))
        #expect(PixelFont.glyph(for: "ä") == PixelFont.glyph(for: "a"))
    }

    @Test func charactersWithoutAGlyphBecomeAQuestionMark() {
        #expect(PixelFont.glyph(for: "ł") == PixelFont.glyph(for: "?"))
        #expect(PixelFont.glyph(for: "🐑") == PixelFont.glyph(for: "?"))
        #expect(PixelFont.glyph(for: "\t") == PixelFont.glyph(for: " "))
    }

    @Test func spriteDrawsTheInkInTheGivenColor() {
        let sprite = PixelFont.sprite(for: "i:", color: Self.white)
        #expect(sprite.width == PixelFont.width(of: "i:"))
        #expect(sprite.height == PixelFont.height)
        #expect(sprite.color(x: 0, y: 0) == Self.white)
        #expect(sprite.color(x: 0, y: 1) == nil)
        // The spacing column between the glyphs stays empty.
        #expect((0..<sprite.height).allSatisfy { sprite.color(x: 1, y: $0) == nil })
        #expect(sprite.color(x: 2, y: 2) == Self.white)
    }

    // MARK: Truncation

    @Test func aTextThatFitsIsKept() {
        let plate = NamePlate(prefix: "buddr", title: "test123", more: 2)
        #expect(PixelFont.truncated(plate, maxWidth: 100) == "buddr · test123  +2")
    }

    @Test func onlyTheTitleIsShortened() {
        let plate = NamePlate(prefix: "Devbox · api", title: "Refactor-the-escape-route-of-the-sheep", more: 2)
        let text = PixelFont.truncated(plate, maxWidth: 150)
        #expect(text.hasPrefix("Devbox · api · Refactor"))
        #expect(text.hasSuffix("…  +2"))
        #expect(PixelFont.width(of: text) <= 150)
        // As long as possible: one more character would not fit.
        let kept = text.dropFirst("Devbox · api · ".count).dropLast("…  +2".count)
        let longer = plate.text(title: String(plate.title.prefix(kept.count + 1)) + "…")
        #expect(PixelFont.width(of: longer) > 150)
    }

    @Test func spacesBeforeTheEllipsisAreDropped() {
        let plate = NamePlate(prefix: "buddr", title: "ab cdefghij", more: 0)
        let maxWidth = PixelFont.width(of: "buddr · ab c")
        #expect(PixelFont.truncated(plate, maxWidth: maxWidth) == "buddr · ab…")
    }

    @Test func theWholeTitleMayGo() {
        let plate = NamePlate(prefix: "buddr", title: "test123", more: 0)
        #expect(PixelFont.truncated(plate, maxWidth: PixelFont.width(of: "buddr · …")) == "buddr · …")
    }

    @Test func aPrefixThatDoesNotFitIsCutAtTheEnd() {
        let plate = NamePlate(prefix: "A very long machine label · workspace", title: "title", more: 3)
        let text = PixelFont.truncated(plate, maxWidth: 60)
        #expect(text.hasPrefix("A very"))
        #expect(text.hasSuffix("…"))
        #expect(PixelFont.width(of: text) <= 60)
        #expect(PixelFont.truncated(NamePlate(prefix: "buddr", title: "", more: 0), maxWidth: 2) == "")
    }
}
