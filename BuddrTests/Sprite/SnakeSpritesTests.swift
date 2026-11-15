import Testing

@testable import Buddr

struct SnakeSpritesTests {
    @Test(arguments: SnakeSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(SnakeSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: SnakeSprites.palette) == [])
    }
}
