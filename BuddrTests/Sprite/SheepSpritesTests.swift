import Testing

@testable import Buddr

struct SheepSpritesTests {
    @Test(arguments: SheepSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(SheepSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: SheepSprites.palette) == [])
    }

    @Test func bodyVariantsShareTheirSize() {
        let bodies = [
            SheepSprites.Body.stand, SheepSprites.Body.trotA, SheepSprites.Body.trotB, SheepSprites.Body.gallop,
            SheepSprites.Body.jump, SheepSprites.Body.lying,
        ]
        #expect(Set(bodies.map(\.width)).count == 1)
        #expect(Set(bodies.map(\.height)).count == 1)
    }

    @Test func headVariantsShareTheirSize() {
        let heads = [
            SheepSprites.Head.normal, SheepSprites.Head.blink, SheepSprites.Head.look, SheepSprites.Head.bleat,
            SheepSprites.Head.content, SheepSprites.Head.yawn,
        ]
        #expect(Set(heads.map(\.width)).count == 1)
        #expect(Set(heads.map(\.height)).count == 1)
    }

    @Test func plateFramesTheTextWithCutCorners() {
        typealias Plate = SheepSprites.Plate
        let sprite = Plate.sprite(for: "buddr")
        #expect(sprite.width == PixelFont.width(of: "buddr") + 2 * Plate.paddingX)
        #expect(sprite.height == Plate.paddingTop + PixelFont.height + Plate.paddingBottom)
        let last = (x: sprite.width - 1, y: sprite.height - 1)
        for (x, y) in [(0, 0), (last.x, 0), (0, last.y), (last.x, last.y)] {
            #expect(sprite.color(x: x, y: y) == nil, "corner (\(x), \(y))")
        }
        #expect(sprite.color(x: 1, y: 0) == Plate.fill)
        #expect(sprite.color(x: 0, y: 1) == Plate.fill)
        // The stem of the "b" in the top-left corner of the text, the empty pixel next to it.
        #expect(sprite.color(x: Plate.paddingX, y: Plate.paddingTop) == Plate.text)
        #expect(sprite.color(x: Plate.paddingX + 1, y: Plate.paddingTop) == Plate.fill)
    }
}
