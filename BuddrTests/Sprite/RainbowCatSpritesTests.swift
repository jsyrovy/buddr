import Testing

@testable import Buddr

struct RainbowCatSpritesTests {
    @Test(arguments: RainbowCatSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(RainbowCatSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: RainbowCatSprites.palette) == [])
    }

    @Test func headVariantsShareTheirSize() {
        let heads = RainbowCatSprites.Head.allCases.map(\.sprite)
        #expect(Set(heads.map(\.width)).count == 1)
        #expect(Set(heads.map(\.height)).count == 1)
    }

    /// Paddling moves the legs, not the cat: every pose reaches as far down.
    @Test func legsStandingAndPaddlingShareTheirSize() {
        let legs = [RainbowCatSprites.Legs.stand, .forward, .back].map(\.sprite)
        #expect(Set(legs.map(\.width)).count == 1)
        #expect(Set(legs.map(\.height)).count == 1)
    }
}
