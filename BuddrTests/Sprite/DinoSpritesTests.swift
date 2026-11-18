import Testing

@testable import Buddr

struct DinoSpritesTests {
    @Test(arguments: DinoSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(DinoSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: DinoSprites.palette) == [])
    }
}
