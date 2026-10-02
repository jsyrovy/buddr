import Testing

@testable import Buddr

struct PixelSpriteTests {
    private let red = PixelColor(red: 255, green: 0, blue: 0)
    private let black = PixelColor(red: 0, green: 0, blue: 0)
    private var palette: [Character: PixelColor] { ["R": red] }

    @Test func parsesRowsIntoPixels() {
        let sprite = PixelSprite(rows: ["R.", ".R", "RR"], palette: palette)
        #expect(sprite.width == 2)
        #expect(sprite.height == 3)
        #expect(sprite.color(x: 0, y: 0) == red)
        #expect(sprite.color(x: 1, y: 0) == nil)
        #expect(sprite.color(x: 1, y: 2) == red)
    }

    @Test func pixelsOutsideTheSpriteAreTransparent() {
        let sprite = PixelSprite(rows: ["R"], palette: palette)
        #expect(sprite.color(x: -1, y: 0) == nil)
        #expect(sprite.color(x: 1, y: 0) == nil)
        #expect(sprite.color(x: 0, y: 1) == nil)
    }

    @Test func reportsRowsOfDifferentWidth() {
        let problems = PixelSprite.problems(rows: ["RR", "R"], palette: palette)
        #expect(problems == ["row 1 has 1 pixels, expected 2"])
    }

    @Test func reportsUnknownColors() {
        let problems = PixelSprite.problems(rows: ["RX"], palette: palette)
        #expect(problems == ["row 0 uses unknown color 'X'"])
    }

    @Test func reportsEmptySprites() {
        #expect(!PixelSprite.problems(rows: [], palette: palette).isEmpty)
        #expect(!PixelSprite.problems(rows: [""], palette: palette).isEmpty)
    }

    @Test func outlineSurroundsOpaquePixelsIncludingDiagonals() {
        let outlined = PixelSprite(rows: ["R."], palette: palette).outlined(with: black)
        #expect(outlined.width == 4)
        #expect(outlined.height == 3)
        let expected = PixelSprite(rows: ["OOO.", "ORO.", "OOO."], palette: ["R": red, "O": black])
        #expect(outlined == expected)
    }
}
