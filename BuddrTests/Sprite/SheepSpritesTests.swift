import Testing

@testable import Buddr

struct SheepSpritesTests {
    @Test(arguments: SheepSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(SheepSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: SheepSprites.palette) == [])
    }

    @Test func gridNamesAreUnique() {
        let names = SheepSprites.allGrids.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func bodyVariantsShareTheirSize() {
        let bodies = [
            SheepSprites.Body.stand, SheepSprites.Body.trotA, SheepSprites.Body.trotB, SheepSprites.Body.jump,
            SheepSprites.Body.lying,
        ]
        #expect(Set(bodies.map(\.width)).count == 1)
        #expect(Set(bodies.map(\.height)).count == 1)
    }

    @Test func headVariantsShareTheirSize() {
        let heads = [
            SheepSprites.Head.normal, SheepSprites.Head.blink, SheepSprites.Head.look, SheepSprites.Head.bleat,
        ]
        #expect(Set(heads.map(\.width)).count == 1)
        #expect(Set(heads.map(\.height)).count == 1)
    }

    @Test func standingSheepFitsOnTheCanvas() {
        for layer in SheepSprites.standingFrame.layers {
            #expect(layer.x >= 0 && layer.x + layer.sprite.width <= SheepSprites.canvasWidth)
            #expect(layer.y >= 0 && layer.y + layer.sprite.height <= SheepSprites.canvasHeight)
        }
    }
}
