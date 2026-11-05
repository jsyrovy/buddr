import Testing

@testable import Buddr

struct CorgiSpritesTests {
    @Test(arguments: CorgiSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(CorgiSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: CorgiSprites.palette) == [])
    }
}
