import Testing

@testable import Buddr

struct SheepSpritesTests {
    @Test(arguments: SheepSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(SheepSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: SheepSprites.palette) == [])
    }

    @Test func standingSheepFitsOnTheCanvas() {
        for layer in SheepSprites.standingFrame.layers {
            #expect(layer.x >= 0 && layer.x + layer.sprite.width <= SheepSprites.canvasWidth)
            #expect(layer.y >= 0 && layer.y + layer.sprite.height <= SheepSprites.canvasHeight)
        }
    }
}
