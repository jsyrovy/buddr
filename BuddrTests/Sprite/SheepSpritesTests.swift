import Testing

@testable import Buddr

struct SheepSpritesTests {
    @Test(arguments: SheepSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(SheepSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: SheepSprites.palette) == [])
    }

    @Test func bodyVariantsShareTheirSize() {
        let bodies = SheepSprites.Body.allCases.map(\.sprite)
        #expect(Set(bodies.map(\.width)).count == 1)
        #expect(Set(bodies.map(\.height)).count == 1)
    }

    @Test func headVariantsShareTheirSize() {
        let heads = SheepSprites.Head.allCases.map(\.sprite)
        #expect(Set(heads.map(\.width)).count == 1)
        #expect(Set(heads.map(\.height)).count == 1)
    }
}
