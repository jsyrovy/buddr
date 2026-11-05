import Testing

@testable import Buddr

struct UFOSpritesTests {
    @Test(arguments: UFOSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(UFOSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: UFOSprites.palette) == [])
    }

    /// The beam's stripes move, its outline doesn't.
    @Test func beamPhasesShareTheirSize() {
        let beams = [UFOSprites.Beam.a, .b].map(\.sprite)
        #expect(Set(beams.map(\.width)).count == 1)
        #expect(Set(beams.map(\.height)).count == 1)
    }
}
