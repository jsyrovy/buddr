// All pixel data of the sheep lives in this file, so the character can be redesigned or swapped in one place.
// The current sheep is a placeholder.

enum SheepSprites {
    /// Size of the sprite canvas in pixels: the sheep plus room for effects above it.
    static let canvasWidth = 20
    static let canvasHeight = 18
    /// Where the top-left corner of the sheep sits on the canvas when standing.
    static let sheepX = 2
    static let sheepY = 6

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": PixelColor(red: 0x2A, green: 0x24, blue: 0x30),  // outline
        "W": PixelColor(red: 0xF7, green: 0xF4, blue: 0xEC),  // wool
        "w": PixelColor(red: 0xD6, green: 0xCF, blue: 0xC2),  // wool shade
        "F": PixelColor(red: 0x5A, green: 0x4E, blue: 0x5E),  // face and legs
        "E": PixelColor(red: 0xFF, green: 0xFF, blue: 0xFF),  // eye
        "P": PixelColor(red: 0xF0, green: 0xA3, blue: 0xB0),  // ear
    ]

    static let outline = palette["O"]!

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        static let stand = [
            ".......OO.OO....",
            "..OO..OWWOWWOO..",
            ".OWWO.OWWWWWWWO.",
            "OPWWWOWWWWWWWWWO",
            "OFFFFOWWWWWWWWWO",
            "OFEOFFOWWWWWWWwO",
            "OFFFFFOWWWWWWwwO",
            ".OFFFOWWWWWWwwwO",
            "..OOOWwwwwwwwwO.",
            ".....OFO...OFO..",
            ".....OFO...OFO..",
            ".....OOO...OOO..",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("stand", Grid.stand)
    ]

    // MARK: Sprites

    static let stand = sprite(Grid.stand)

    // MARK: Frames

    static let standingFrame = SpriteFrame(layers: [SpriteLayer(sprite: stand, x: sheepX, y: sheepY)])

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
