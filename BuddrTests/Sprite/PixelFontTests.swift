import Testing

@testable import Buddr

struct PixelFontTests {
    private static let white = PixelColor(red: 255, green: 255, blue: 255)

    @Test(arguments: PixelFont.glyphs.keys.sorted())
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

    // MARK: Shortening

    @Test func aTextThatFitsIsKept() {
        #expect(
            PixelFont.shortened("test123", between: "buddr · ", and: "  +2", maxWidth: 100) == "buddr · test123  +2")
        #expect(PixelFont.shortened("", maxWidth: 0) == "")
    }

    @Test func onlyTheMiddleIsShortenedAsLittleAsPossible() throws {
        let title = "Refactor-the-escape-route"
        let text = try #require(PixelFont.shortened(title, between: "buddr · ", and: "  +2", maxWidth: 110))
        #expect(text.hasPrefix("buddr · Refactor"))
        #expect(text.hasSuffix("…  +2"))
        #expect(PixelFont.width(of: text) <= 110)
        // One more character would not fit.
        let kept = text.dropFirst("buddr · ".count).dropLast("…  +2".count)
        #expect(PixelFont.width(of: "buddr · " + title.prefix(kept.count + 1) + "…  +2") > 110)
    }

    @Test func spacesBeforeTheEllipsisAreDropped() {
        let maxWidth = PixelFont.width(of: "ab c")
        #expect(PixelFont.shortened("ab cdefghij", maxWidth: maxWidth) == "ab…")
    }

    @Test func theWholeMiddleMayGo() {
        #expect(
            PixelFont.shortened("test123", between: "buddr · ", maxWidth: PixelFont.width(of: "buddr · …"))
                == "buddr · …")
    }

    @Test func nothingWhenNotEvenTheEllipsisFits() {
        #expect(PixelFont.shortened("test123", between: "buddr · ", maxWidth: 30) == nil)
        #expect(PixelFont.shortened("buddr", maxWidth: 2) == nil)
    }
}
