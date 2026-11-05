import Testing

@testable import Buddr

struct EarthSpritesTests {
    @Test(arguments: EarthSprites.allGrids.map(\.name))
    func gridIsValid(name: String) throws {
        let grid = try #require(EarthSprites.allGrids.first { $0.name == name })
        #expect(PixelSprite.problems(rows: grid.rows, palette: EarthSprites.palette) == [])
    }

    /// Turning changes only what is inside the outline, which is filled completely.
    @Test(arguments: [0, 7, 31])
    func globeKeepsItsOutlineWhileTurning(turn: Int) {
        let globe = EarthSprites.Grid.globe(turn: turn)
        #expect(globe.map { $0.map { $0 == "O" } } == EarthSprites.Grid.disc.map { $0.map { $0 == "O" } })
        #expect(
            globe.map { $0.map { $0 == "." } }
                == EarthSprites.Grid.disc.map { row in
                    let first = row.firstIndex(of: "O")!, last = row.lastIndex(of: "O")!
                    return row.indices.map { $0 < first || $0 > last }
                })
    }

    /// The map wraps around: a whole turn comes back to the start.
    @Test func wholeTurnComesBack() {
        let columns = EarthSprites.Grid.map[0].count
        #expect(EarthSprites.Grid.globe(turn: columns) == EarthSprites.Grid.globe(turn: 0))
        #expect(EarthSprites.Grid.globe(turn: -1) == EarthSprites.Grid.globe(turn: columns - 1))
    }

    @Test func nightIsDarkWithCityLights() {
        let night = EarthSprites.Grid.globe(turn: 0, night: true).joined()
        #expect(night.contains("Y"))
        #expect(!night.contains("L") && !night.contains("B"))
    }
}
