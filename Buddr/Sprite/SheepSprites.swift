// All pixel data of the sheep lives in this file, so the character can be redesigned or swapped in one place: the
// palette, the grids, how they are composed into frames, and the frame timing of every animation clip.
// The current sheep is a placeholder.

enum SheepSprites {
    /// Size of the sprite canvas in pixels: the sheep plus room for effects above and behind it.
    static let canvasWidth = 22
    static let canvasHeight = 20
    /// Top-left corner of the sheep body on the canvas when standing.
    static let sheepX = 3
    static let sheepY = 8
    /// Offset of the head relative to the body.
    static let headX = 0
    static let headY = 1
    /// Opacity of the whole picture while the state is unknown.
    static let unknownOpacity = 0.45

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": PixelColor(red: 0x2A, green: 0x24, blue: 0x30),  // outline
        "W": PixelColor(red: 0xF7, green: 0xF4, blue: 0xEC),  // wool
        "w": PixelColor(red: 0xD6, green: 0xCF, blue: 0xC2),  // wool shade, dust
        "F": PixelColor(red: 0x5A, green: 0x4E, blue: 0x5E),  // face and legs
        "E": PixelColor(red: 0xFF, green: 0xFF, blue: 0xFF),  // eye
        "P": PixelColor(red: 0xF0, green: 0xA3, blue: 0xB0),  // ear, open mouth
        "R": PixelColor(red: 0xE5, green: 0x48, blue: 0x4D),  // "!"
        "G": PixelColor(red: 0x2F, green: 0xA8, blue: 0x4F),  // check mark
        "Q": PixelColor(red: 0x7A, green: 0xA2, blue: 0xF7),  // "?"
        "Z": PixelColor(red: 0x9A, green: 0xC0, blue: 0xFF),  // "z"
    ]

    static let outline = palette["O"]!

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The body is drawn first and the head on top of it, at (headX, headY) relative to the body.

        static let bodyStand = [
            ".......OO.OO....",
            "......OWWOWWOO..",
            "......OWWWWWWWO.",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWwO",
            ".....OWWWWWWWwwO",
            ".....OWWWWWWwwwO",
            ".....OwwwwwwwwO.",
            ".....OFO...OFO..",
            ".....OFO...OFO..",
            ".....OOO...OOO..",
        ]

        static let bodyTrotA = [
            ".......OO.OO....",
            "......OWWOWWOO..",
            "......OWWWWWWWO.",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWwO",
            ".....OWWWWWWWwwO",
            ".....OWWWWWWwwwO",
            ".....OwwwwwwwwO.",
            ".....OFO...OFO..",
            "....OFO.....OFO.",
            "....OOO.....OOO.",
        ]

        static let bodyTrotB = [
            ".......OO.OO....",
            "......OWWOWWOO..",
            "......OWWWWWWWO.",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWwO",
            ".....OWWWWWWWwwO",
            ".....OWWWWWWwwwO",
            ".....OwwwwwwwwO.",
            ".....OFO...OFO..",
            "......OFO.OFO...",
            "......OOO.OOO...",
        ]

        /// Legs tucked in, for jumps.
        static let bodyJump = [
            ".......OO.OO....",
            "......OWWOWWOO..",
            "......OWWWWWWWO.",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWwO",
            ".....OWWWWWWWwwO",
            ".....OWWWWWWwwwO",
            ".....OwwwwwwwwO.",
            ".....OFO...OFO..",
            ".....OOO...OOO..",
            "................",
        ]

        /// Lying down, two pixels lower, legs folded.
        static let bodyLying = [
            "................",
            "................",
            ".......OO.OO....",
            "......OWWOWWOO..",
            "......OWWWWWWWO.",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWwO",
            ".....OWWWWWWWwwO",
            ".....OWWWWWWwwwO",
            ".....OwwwwwwwwO.",
            "....OFFOOOOFFO..",
        ]

        static let head = [
            "..OO...",
            ".OWWO..",
            "OPWWWO.",
            "OFFFFO.",
            "OFEOFFO",
            "OFFFFFO",
            ".OFFFO.",
            "..OOO..",
        ]

        static let headBlink = [
            "..OO...",
            ".OWWO..",
            "OPWWWO.",
            "OFFFFO.",
            "OFOOFFO",
            "OFFFFFO",
            ".OFFFO.",
            "..OOO..",
        ]

        /// Eye turned forward.
        static let headLook = [
            "..OO...",
            ".OWWO..",
            "OPWWWO.",
            "OFFFFO.",
            "OEOFFFO",
            "OFFFFFO",
            ".OFFFO.",
            "..OOO..",
        ]

        /// Mouth open, bleating.
        static let headBleat = [
            "..OO...",
            ".OWWO..",
            "OPWWWO.",
            "OFFFFO.",
            "OFEOFFO",
            "OFFFFFO",
            ".OPPFO.",
            "..OOO..",
        ]

        static let checkBubble = [
            ".OOOOOOO.",
            "OWWWWWWWO",
            "OWWWWWGWO",
            "OWWWWGWWO",
            "OWGWGWWWO",
            "OWWGWWWWO",
            "OWWWWWWWO",
            ".OOOWOOO.",
            "...OWO...",
            "....O....",
        ]

        // Effect glyphs without outline; the outline is added when building the sprite.

        static let exclamation = [
            "R",
            "R",
            "R",
            ".",
            "R",
        ]

        static let question = [
            ".QQ.",
            "Q..Q",
            "...Q",
            "..Q.",
            "....",
            "..Q.",
        ]

        static let smallZ = [
            "ZZZZ",
            "..Z.",
            ".Z..",
            "ZZZZ",
        ]

        static let largeZ = [
            "ZZZZZ",
            "...Z.",
            "..Z..",
            ".Z...",
            "ZZZZZ",
        ]

        static let smallDust = [
            "ww"
        ]

        static let largeDust = [
            ".w.",
            "www",
        ]

        /// A single flying bit of wool, deliberately without outline.
        static let fleck = [
            "W"
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("bodyStand", Grid.bodyStand),
        ("bodyTrotA", Grid.bodyTrotA),
        ("bodyTrotB", Grid.bodyTrotB),
        ("bodyJump", Grid.bodyJump),
        ("bodyLying", Grid.bodyLying),
        ("head", Grid.head),
        ("headBlink", Grid.headBlink),
        ("headLook", Grid.headLook),
        ("headBleat", Grid.headBleat),
        ("checkBubble", Grid.checkBubble),
        ("exclamation", Grid.exclamation),
        ("question", Grid.question),
        ("smallZ", Grid.smallZ),
        ("largeZ", Grid.largeZ),
        ("smallDust", Grid.smallDust),
        ("largeDust", Grid.largeDust),
        ("fleck", Grid.fleck),
    ]

    // MARK: Sprites

    enum Body {
        static let stand = sprite(Grid.bodyStand)
        static let trotA = sprite(Grid.bodyTrotA)
        static let trotB = sprite(Grid.bodyTrotB)
        static let jump = sprite(Grid.bodyJump)
        static let lying = sprite(Grid.bodyLying)
    }

    enum Head {
        static let normal = sprite(Grid.head)
        static let blink = sprite(Grid.headBlink)
        static let look = sprite(Grid.headLook)
        static let bleat = sprite(Grid.headBleat)
    }

    enum Effect {
        static let checkBubble = sprite(Grid.checkBubble)
        static let exclamation = sprite(Grid.exclamation).outlined(with: outline)
        static let question = sprite(Grid.question).outlined(with: outline)
        static let smallZ = sprite(Grid.smallZ).outlined(with: outline)
        static let largeZ = sprite(Grid.largeZ).outlined(with: outline)
        static let smallDust = sprite(Grid.smallDust).outlined(with: outline)
        static let largeDust = sprite(Grid.largeDust).outlined(with: outline)
        static let fleck = sprite(Grid.fleck)
    }

    // MARK: Frames

    static let standingFrame = SpriteFrame(layers: sheep())

    /// Body and head layers; `dy` moves the whole sheep (negative is up), `headDY` only the head.
    static func sheep(
        body: PixelSprite = Body.stand, head: PixelSprite = Head.normal, dy: Int = 0, headDY: Int = 0
    ) -> [SpriteLayer] {
        [
            SpriteLayer(sprite: body, x: sheepX, y: sheepY + dy),
            SpriteLayer(sprite: head, x: sheepX + headX, y: sheepY + headY + dy + headDY),
        ]
    }

    private static func effect(_ sprite: PixelSprite, _ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: sprite, x: x, y: y)
    }

    private static func frame(
        _ milliseconds: Int, _ layers: [SpriteLayer], opacity: Double = 1
    ) -> AnimationFrame {
        AnimationFrame(sprite: SpriteFrame(layers: layers, opacity: opacity), duration: .milliseconds(milliseconds))
    }

    // MARK: Clips

    // Keep every clip short (well under 1.5 s): a clip always plays to its end before the state machine switches.

    static let clips: [SheepClipID: AnimationClip] = [
        .idleRest: AnimationClip([
            frame(1_000, sheep())
        ]),
        .idleBlink: AnimationClip([
            frame(150, sheep(head: Head.blink)),
            frame(250, sheep()),
        ]),
        .idleLook: AnimationClip([
            frame(700, sheep(head: Head.look, headDY: -1)),
            frame(300, sheep()),
        ]),
        .sleeping: AnimationClip([
            frame(700, sheep(body: Body.lying, head: Head.blink, headDY: 2) + [effect(Effect.smallZ, 9, 4)]),
            frame(
                700,
                sheep(body: Body.lying, head: Head.blink, headDY: 2) + [
                    effect(Effect.smallZ, 9, 4), effect(Effect.largeZ, 13, 0),
                ]),
        ]),
        .working: AnimationClip([
            frame(150, sheep(body: Body.trotA) + [effect(Effect.largeDust, 17, 16), effect(Effect.fleck, 20, 7)]),
            frame(
                150,
                sheep(dy: -1) + [
                    effect(Effect.smallDust, 18, 17), effect(Effect.fleck, 21, 5), effect(Effect.fleck, 18, 6),
                ]),
            frame(150, sheep(body: Body.trotB) + [effect(Effect.largeDust, 17, 16), effect(Effect.fleck, 19, 4)]),
            frame(150, sheep(dy: -1) + [effect(Effect.smallDust, 18, 17), effect(Effect.fleck, 20, 2)]),
        ]),
        .blocked: AnimationClip([
            frame(150, sheep(head: Head.bleat) + [effect(Effect.exclamation, 1, 0)]),
            frame(120, sheep(body: Body.jump, head: Head.bleat, dy: -2) + [effect(Effect.exclamation, 1, 0)]),
            frame(120, sheep(body: Body.jump, dy: -3)),
            frame(120, sheep(body: Body.jump, dy: -2)),
            frame(150, sheep() + [effect(Effect.exclamation, 1, 0)]),
            frame(340, sheep()),
        ]),
        .doneJump: AnimationClip([
            frame(150, sheep() + [effect(Effect.checkBubble, 0, 0)]),
            frame(120, sheep(body: Body.jump, dy: -2) + [effect(Effect.checkBubble, 0, 0)]),
            frame(120, sheep(body: Body.jump, dy: -3) + [effect(Effect.checkBubble, 0, 0)]),
            frame(120, sheep(body: Body.jump, dy: -2) + [effect(Effect.checkBubble, 0, 0)]),
            frame(290, sheep(head: Head.blink) + [effect(Effect.checkBubble, 0, 0)]),
        ]),
        .doneHold: AnimationClip([
            frame(600, sheep(head: Head.blink) + [effect(Effect.checkBubble, 0, 0)]),
            frame(400, sheep() + [effect(Effect.checkBubble, 0, 0)]),
        ]),
        .unknown: AnimationClip([
            frame(800, sheep() + [effect(Effect.question, 0, 1)], opacity: unknownOpacity),
            frame(800, sheep() + [effect(Effect.question, 0, 0)], opacity: unknownOpacity),
        ]),
    ]

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
