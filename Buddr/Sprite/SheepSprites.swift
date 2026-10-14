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
    /// Size of one menu bar icon pixel in points: a whole number of device pixels on every display.
    static let menuBarIconPointsPerPixel = 1.0

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
        "H": PixelColor(red: 0xF2, green: 0x55, blue: 0x7A),  // heart
    ]

    static let outline = palette["O"]!

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The body is drawn first and the head on top of it, at (headX, headY) relative to the body. Body variants
        // differ only in their legs; head variants only in the eye or mouth row.

        private static let wool = [
            ".......OO.OO....",
            "......OWWOWWOO..",
            "......OWWWWWWWO.",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWWO",
            ".....OWWWWWWWWwO",
            ".....OWWWWWWWwwO",
            ".....OWWWWWWwwwO",
            ".....OwwwwwwwwO.",
        ]
        private static let hips = ".....OFO...OFO.."

        static let bodyStand = wool + [hips, hips, ".....OOO...OOO.."]
        static let bodyTrotA = wool + [hips, "....OFO.....OFO.", "....OOO.....OOO."]
        static let bodyTrotB = wool + [hips, "......OFO.OFO...", "......OOO.OOO..."]
        /// Legs stretched far apart, for running.
        static let bodyGallop = wool + [hips, "....OFO.....OFO.", "...OOO.......OOO"]
        /// Legs tucked in, for jumps.
        static let bodyJump = wool + [hips, ".....OOO...OOO..", "................"]
        /// Lying down, two pixels lower, legs folded.
        static let bodyLying = ["................", "................"] + wool + ["....OFFOOOOFFO.."]

        private static func head(eye: String = "OFEOFFO", mouth: String = ".OFFFO.") -> [String] {
            [
                "..OO...",
                ".OWWO..",
                "OPWWWO.",
                "OFFFFO.",
                eye,
                "OFFFFFO",
                mouth,
                "..OOO..",
            ]
        }

        static let headNormal = head()
        static let headBlink = head(eye: "OFOOFFO")
        /// Eye turned forward.
        static let headLook = head(eye: "OEOFFFO")
        /// Mouth open, bleating.
        static let headBleat = head(mouth: ".OPPFO.")
        /// Eye closed and a blushing cheek, enjoying being petted.
        static let headContent = [
            "..OO...",
            ".OWWO..",
            "OPWWWO.",
            "OFFFFO.",
            "OFOOFFO",
            "OPFFFFO",
            ".OFFFO.",
            "..OOO..",
        ]
        /// Eye closed and the mouth wide open, yawning.
        static let headYawn = [
            "..OO...",
            ".OWWO..",
            "OPWWWO.",
            "OFFFFO.",
            "OFOOFFO",
            "OPPFFFO",
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

        static let smallHeart = [
            "HH.HH",
            "HHHHH",
            ".HHH.",
            "..H..",
        ]

        static let largeHeart = [
            ".HH.HH.",
            "HHHHHHH",
            "HHHHHHH",
            ".HHHHH.",
            "..HHH..",
            "...H...",
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

        /// The sheep as a one-color silhouette for the menu bar, where only the shape counts (the system tints it).
        /// Drawn for the small size rather than taken from the sprites: wool, head and legs are filled, a gap keeps
        /// the head apart from the body and the eye is a hole.
        static let menuBarIcon = [
            "..........OO..OO....",
            "......OO.OOOOOOOOO..",
            ".....OOOOOOOOOOOOOO.",
            "..OOO.OOOOOOOOOOOOOO",
            ".OOOOO.OOOOOOOOOOOOO",
            "OOOOOOO.OOOOOOOOOOOO",
            "OO.OOOO.OOOOOOOOOOOO",
            "OOOOOOO.OOOOOOOOOOOO",
            ".OOOOO.OOOOOOOOOOOOO",
            "..OOO..OOOOOOOOOOOO.",
            ".......OOOOOOOOOOOO.",
            "........OO.OO.OO.O..",
            "........O.O....O.O..",
            "........O.O....O.O..",
            "........O.O....O.O..",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("bodyStand", Grid.bodyStand),
        ("bodyTrotA", Grid.bodyTrotA),
        ("bodyTrotB", Grid.bodyTrotB),
        ("bodyGallop", Grid.bodyGallop),
        ("bodyJump", Grid.bodyJump),
        ("bodyLying", Grid.bodyLying),
        ("headNormal", Grid.headNormal),
        ("headBlink", Grid.headBlink),
        ("headLook", Grid.headLook),
        ("headBleat", Grid.headBleat),
        ("headContent", Grid.headContent),
        ("headYawn", Grid.headYawn),
        ("checkBubble", Grid.checkBubble),
        ("exclamation", Grid.exclamation),
        ("question", Grid.question),
        ("smallZ", Grid.smallZ),
        ("largeZ", Grid.largeZ),
        ("smallHeart", Grid.smallHeart),
        ("largeHeart", Grid.largeHeart),
        ("smallDust", Grid.smallDust),
        ("largeDust", Grid.largeDust),
        ("fleck", Grid.fleck),
        ("menuBarIcon", Grid.menuBarIcon),
    ]

    // MARK: Sprites

    enum Body {
        static let stand = sprite(Grid.bodyStand)
        static let trotA = sprite(Grid.bodyTrotA)
        static let trotB = sprite(Grid.bodyTrotB)
        static let gallop = sprite(Grid.bodyGallop)
        static let jump = sprite(Grid.bodyJump)
        static let lying = sprite(Grid.bodyLying)
    }

    enum Head {
        static let normal = sprite(Grid.headNormal)
        static let blink = sprite(Grid.headBlink)
        static let look = sprite(Grid.headLook)
        static let bleat = sprite(Grid.headBleat)
        static let content = sprite(Grid.headContent)
        static let yawn = sprite(Grid.headYawn)
    }

    enum Effect {
        static let checkBubble = sprite(Grid.checkBubble)
        static let exclamation = sprite(Grid.exclamation).outlined(with: outline)
        static let question = sprite(Grid.question).outlined(with: outline)
        static let smallZ = sprite(Grid.smallZ).outlined(with: outline)
        static let largeZ = sprite(Grid.largeZ).outlined(with: outline)
        static let smallHeart = sprite(Grid.smallHeart).outlined(with: outline)
        static let largeHeart = sprite(Grid.largeHeart).outlined(with: outline)
        static let smallDust = sprite(Grid.smallDust).outlined(with: outline)
        static let largeDust = sprite(Grid.largeDust).outlined(with: outline)
        static let fleck = sprite(Grid.fleck)
    }

    static let menuBarIcon = sprite(Grid.menuBarIcon)

    // MARK: Frames

    /// Body and head layers; `dy` moves the whole sheep (negative is up), `headDY` only the head.
    static func sheep(
        body: PixelSprite = Body.stand, head: PixelSprite = Head.normal, dy: Int = 0, headDY: Int = 0
    ) -> [SpriteLayer] {
        [
            SpriteLayer(sprite: body, x: sheepX, y: sheepY + dy),
            SpriteLayer(sprite: head, x: sheepX + headX, y: sheepY + headY + dy + headDY),
        ]
    }

    private static let checkBubble = SpriteLayer(sprite: Effect.checkBubble, x: 0, y: 0)
    private static let exclamation = SpriteLayer(sprite: Effect.exclamation, x: 1, y: 0)
    private static let asleep = sheep(body: Body.lying, head: Head.blink, headDY: 2)
    private static let smallZ = SpriteLayer(sprite: Effect.smallZ, x: 9, y: 4)
    private static let largeZ = SpriteLayer(sprite: Effect.largeZ, x: 13, y: 0)
    private static let largeDust = SpriteLayer(sprite: Effect.largeDust, x: 17, y: 16)
    private static let smallDust = SpriteLayer(sprite: Effect.smallDust, x: 18, y: 17)

    private static func fleck(_ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Effect.fleck, x: x, y: y)
    }

    private static func smallHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Effect.smallHeart, x: 3, y: y)
    }

    private static func largeHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Effect.largeHeart, x: 2, y: y)
    }

    private static func question(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Effect.question, x: 0, y: y)
    }

    private static func frame(
        _ milliseconds: Int, _ layers: [SpriteLayer], opacity: Double = 1
    ) -> AnimationFrame {
        AnimationFrame(sprite: SpriteFrame(layers: layers, opacity: opacity), duration: .milliseconds(milliseconds))
    }

    // MARK: Clips

    // Keep every clip short (well under 1.5 s): a clip always plays to its end before the state machine switches.

    static func clip(_ id: SheepClipID) -> AnimationClip {
        switch id {
        case .idleRest: Clip.idleRest
        case .idleBlink: Clip.idleBlink
        case .idleLook: Clip.idleLook
        case .sleeping: Clip.sleeping
        case .working: Clip.working
        case .blocked: Clip.blocked
        case .doneJump: Clip.doneJump
        case .doneHold: Clip.doneHold
        case .unknown: Clip.unknown
        case .idleStill: Clip.idleStill
        case .sleepingStill: Clip.sleepingStill
        case .workingStill: Clip.workingStill
        case .blockedStill: Clip.blockedStill
        case .doneStill: Clip.doneStill
        case .unknownStill: Clip.unknownStill
        }
    }

    private enum Clip {
        static let idleRest = AnimationClip([
            frame(1_000, sheep())
        ])
        static let idleBlink = AnimationClip([
            frame(150, sheep(head: Head.blink)),
            frame(250, sheep()),
        ])
        static let idleLook = AnimationClip([
            frame(700, sheep(head: Head.look, headDY: -1)),
            frame(300, sheep()),
        ])
        static let sleeping = AnimationClip([
            frame(700, asleep + [smallZ]),
            frame(700, asleep + [smallZ, largeZ]),
        ])
        static let working = AnimationClip([
            frame(150, sheep(body: Body.trotA) + [largeDust, fleck(20, 7)]),
            frame(150, sheep(dy: -1) + [smallDust, fleck(21, 5), fleck(18, 6)]),
            frame(150, sheep(body: Body.trotB) + [largeDust, fleck(19, 4)]),
            frame(150, sheep(dy: -1) + [smallDust, fleck(20, 2)]),
        ])
        static let blocked = AnimationClip([
            frame(150, sheep(head: Head.bleat) + [exclamation]),
            frame(120, sheep(body: Body.jump, head: Head.bleat, dy: -2) + [exclamation]),
            frame(120, sheep(body: Body.jump, dy: -3)),
            frame(120, sheep(body: Body.jump, dy: -2)),
            frame(150, sheep() + [exclamation]),
            frame(340, sheep()),
        ])
        static let doneJump = AnimationClip([
            frame(150, sheep() + [checkBubble]),
            frame(120, sheep(body: Body.jump, dy: -2) + [checkBubble]),
            frame(120, sheep(body: Body.jump, dy: -3) + [checkBubble]),
            frame(120, sheep(body: Body.jump, dy: -2) + [checkBubble]),
            frame(290, sheep(head: Head.blink) + [checkBubble]),
        ])
        static let doneHold = AnimationClip([
            frame(600, sheep(head: Head.blink) + [checkBubble]),
            frame(400, sheep() + [checkBubble]),
        ])
        static let unknown = AnimationClip([
            frame(800, sheep() + [question(1)], opacity: unknownOpacity),
            frame(800, sheep() + [question(0)], opacity: unknownOpacity),
        ])

        // Still poses: one picture per state that still shows the state's sign, mostly a frame of its clip.
        static let idleStill = still(idleRest.frames[0].sprite)
        static let sleepingStill = still(sleeping.frames[1].sprite)
        static let workingStill = still(
            SpriteFrame(layers: sheep(body: Body.trotA) + [largeDust, fleck(20, 7), fleck(19, 4)]))
        static let blockedStill = still(blocked.frames[0].sprite)
        static let doneStill = still(doneHold.frames[1].sprite)
        static let unknownStill = still(unknown.frames[1].sprite)

        /// The frame is short only so that a state change shows promptly; repeating it changes nothing on screen.
        private static func still(_ sprite: SpriteFrame) -> AnimationClip {
            AnimationClip([AnimationFrame(sprite: sprite, duration: .milliseconds(500))])
        }
    }

    // MARK: Escape

    /// Clips of leaving the screen – escaping from a fullscreen window or wandering off bored when it hides – and of
    /// the return. They are played by `SheepEscape` rather than the state machine; the sheep faces left, moving right
    /// uses the mirrored frames.
    enum Escape {
        /// A startled hop with an open mouth before running away.
        static let startle = AnimationClip([
            frame(120, sheep(head: Head.bleat)),
            frame(100, sheep(body: Body.jump, head: Head.bleat, dy: -2)),
            frame(100, sheep(body: Body.jump, head: Head.bleat, dy: -3)),
            frame(100, sheep(body: Body.jump, dy: -2)),
            frame(80, sheep()),
        ])
        /// A slow yawn with the head raised before wandering off.
        static let yawn = AnimationClip([
            frame(200, sheep()),
            frame(150, sheep(head: Head.blink, headDY: -1)),
            frame(600, sheep(head: Head.yawn, headDY: -1)),
            frame(200, sheep(head: Head.blink)),
            frame(200, sheep()),
        ])
        /// Standing still for a moment, shown mirrored when the sheep turns around.
        static let turn = AnimationClip([
            frame(100, sheep())
        ])
        /// Gallop, looped while the panel moves.
        static let run = AnimationClip([
            frame(80, sheep(body: Body.gallop) + [largeDust]),
            frame(80, sheep(body: Body.jump, dy: -1) + [smallDust]),
            frame(80, sheep(body: Body.trotB)),
            frame(80, sheep(body: Body.jump, dy: -1)),
        ])
        /// A slow walk with the head hanging and bobbing, looped while the panel moves.
        static let walk = AnimationClip([
            frame(180, sheep(body: Body.trotA, headDY: 1)),
            frame(180, sheep()),
            frame(180, sheep(body: Body.trotB, headDY: 1)),
            frame(180, sheep()),
        ])
        /// Catching breath after coming back.
        static let arrive = AnimationClip([
            frame(150, sheep(head: Head.bleat)),
            frame(150, sheep(head: Head.blink)),
            frame(200, sheep()),
        ])
    }

    // MARK: Petting

    /// The reaction to a click: the sheep leans into the hand with its eye closed, a heart rises and it gives a small
    /// happy hop. Played by the driver as an interjection, outside the state machine.
    static let petted = AnimationClip([
        frame(120, sheep(head: Head.content, headDY: 1)),
        frame(160, sheep(head: Head.content) + [smallHeart(3)]),
        frame(160, sheep(head: Head.content, headDY: 1) + [smallHeart(2)]),
        frame(160, sheep(head: Head.content) + [largeHeart(1)]),
        frame(160, sheep(head: Head.content, headDY: 1) + [largeHeart(0)]),
        frame(120, sheep(body: Body.jump, head: Head.content, dy: -1) + [largeHeart(0)]),
        frame(200, sheep(head: Head.content) + [largeHeart(0)]),
        frame(200, sheep()),
    ])

    /// Every clip with a name: the state machine's, the escape's and the petting reaction.
    static let allClips: [(name: String, clip: AnimationClip)] =
        SheepClipID.allCases.map { ("\($0)", clip($0)) } + [
            ("escapeStartle", Escape.startle),
            ("escapeYawn", Escape.yawn),
            ("escapeTurn", Escape.turn),
            ("escapeRun", Escape.run),
            ("escapeWalk", Escape.walk),
            ("escapeArrive", Escape.arrive),
            ("petted", petted),
        ]

    // MARK: Name plate

    /// The plate under the sheep naming the agent it reports (`NamePlate.Label`): light text in `PixelFont` on a dark plate
    /// with cut corners. Drawn with its own, smaller pixels (`NamePlateLayout.plateScale(sheepScale:)`).
    enum Plate {
        /// A plate pixel is this many times smaller than a sheep pixel (rounded down, at least one point).
        static let pixelDivisor = 3
        static let fill = outline
        static let text = palette["W"]!
        /// Plate pixels between the text and the left and right edges.
        static let paddingX = 3
        /// Plate pixels above the text and below its descender rows, so text without descenders looks centered.
        static let paddingTop = 3
        static let paddingBottom = 1
        /// Plate pixels between the sheep's feet and the plate.
        static let gap = 2
        /// Longest text in plate pixels; longer ones are shortened (`text(for:maxWidth:)`).
        static let maxTextWidth = 100
        static let height = paddingTop + PixelFont.height + paddingBottom

        /// The text of `label`, at most `maxWidth` pixels wide: the title is shortened with `…`, keeping the machine
        /// and workspace before it and the `+N` after it. When even those don't fit, the whole text is cut at the end.
        static func text(for label: NamePlate.Label, maxWidth: Int = maxTextWidth) -> String {
            let shortenedTitle =
                label.title.isEmpty
                ? nil
                : PixelFont.shortened(label.title, between: label.lead, and: label.suffix, maxWidth: maxWidth)
            return shortenedTitle ?? PixelFont.shortened(label.text, maxWidth: maxWidth) ?? ""
        }

        static func sprite(for plate: NamePlate.Label) -> PixelSprite {
            let label = PixelFont.sprite(for: text(for: plate), color: Plate.text)
            let width = label.width + 2 * paddingX
            let pixels = (0..<height).flatMap { y in
                (0..<width).map { x -> PixelColor? in
                    let isCorner = (x == 0 || x == width - 1) && (y == 0 || y == height - 1)
                    if isCorner { return nil }
                    return label.color(x: x - paddingX, y: y - paddingTop) ?? fill
                }
            }
            return PixelSprite(width: width, height: height, pixels: pixels)
        }
    }

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
