// All pixel data of the snake lives in this file: the palette, the grids, how they are composed into frames, and the
// frame timing of every animation clip. A green rattlesnake coiled in two rings, its head raised over them and the
// rattle sticking up behind; it swallows eggs while agents work (an egg drops in, a bulge slides down its neck) and
// rattles when it needs the user. The state's signs ("!", the ✔ bubble, "?", "zzz", hearts) are the sheep's
// (`SheepSprites.Effect`), so every buddy shows the same ones.

enum SnakeSprites {
    static let buddy = Buddy(id: .snake, clips: ClipSet(clip), escape: ClipSet(escapeClip), petted: petted)

    /// Top-left corner of the snake on the canvas at rest: 19 × 13 pixels, the lower ring on the bottom row.
    static let snakeX = 2
    static let snakeY = 7

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": SheepSprites.outline,  // outline, eyes
        "G": PixelColor(red: 0x7B, green: 0xC0, blue: 0x43),  // scales
        "g": PixelColor(red: 0x4A, green: 0x8F, blue: 0x3A),  // spots on the back
        "Y": PixelColor(red: 0xF4, green: 0xDC, blue: 0x78),  // belly, lower jaw
        "E": PixelColor(red: 0xFF, green: 0xFF, blue: 0xFF),  // eye glint
        "P": SheepSprites.palette["P"]!,  // open mouth, cheeks
        "R": PixelColor(red: 0xE0, green: 0x4A, blue: 0x5A),  // tongue
        "K": PixelColor(red: 0xE8, green: 0xD2, blue: 0xA0),  // rattle
        "k": PixelColor(red: 0xB8, green: 0x9A, blue: 0x60),  // rattle, shade
        "W": PixelColor(red: 0xFA, green: 0xF5, blue: 0xEB),  // egg
        "w": PixelColor(red: 0xDA, green: 0xD0, blue: 0xC0),  // egg shade
    ]

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The snake is drawn back to front: the coil, the rattle, the neck, the head. Every part has its place in the
        // snake (`snake(head:tongue:raised:rattle:dy:headDY:)`); variants of the head differ only in a row or two.

        private static let openEyes = ["OGEOGGGgGO.", "OGOOGGGGGO."]
        private static let closedEyes = ["OGGGGGGgGO.", "OGOOGGGGGO."]
        private static let closedMouth = ["OGGGGGGGgO.", ".OYYYYYOGGO", "..OOOOOYGGO"]
        private static let blushingMouth = ["OGPGGGGGgO.", ".OYYYYYOGGO", "..OOOOOYGGO"]
        /// The lower jaw dropped and pushed forward.
        private static let openMouth = [".OPPPOGGgO.", "OYYYYYYOGGO", ".OOOOOOYGGO"]

        /// The head turned left, the top of the neck under its back (the bottom two rows).
        private static func head(eyes: [String] = openEyes, mouth: [String] = closedMouth) -> [String] {
            ["..OOOOOO...", ".OGGGGGGO.."] + eyes + mouth
        }

        static let headNormal = head()
        static let headBlink = head(eyes: closedEyes)
        /// Mouth open: hissing, or catching an egg.
        static let headHiss = head(mouth: openMouth)
        /// Eyes closed and the mouth open, yawning.
        static let headYawn = head(eyes: closedEyes, mouth: openMouth)
        /// Eyes closed and a blushing cheek, enjoying being petted.
        static let headContent = head(eyes: closedEyes, mouth: blushingMouth)

        /// Two rings, the upper one with the neck rising out of it and the tail going up at the back of the lower one
        /// into the rattle.
        static let coil = [
            "...OOOOOOOOYGGGO...",
            "..OGGgGGGgGGGGGOGGO",
            ".OOOOOOOOOOOOOOOGGO",
            "OGGgGGGgGGGgGGGgGGO",
            "OGGGGGGGGGGGGGGGGGO",
            ".OOOOOOOOOOOOOOOOO.",
        ]
        /// One row of the neck, added under the head for every pixel it is raised.
        static let neck = [
            "OYGGO"
        ]
        /// The neck swollen by a swallowed egg.
        static let bulge = [
            "OYYGGGO",
            "OYYGGGO",
        ]
        static let rattle = [
            ".OO.",
            "OKKO",
            "OkkO",
            "OKKO",
            "OkkO",
        ]
        /// A forked tongue without outline; the outline is added when building the sprite.
        static let tongue = [
            "R...",
            ".RRR",
            "R...",
        ]
        /// With its outline, so its lower rows alone can come in at the top edge.
        static let egg = [
            ".OOO.",
            "OWWWO",
            "OWWWO",
            "OWWwO",
            ".OOO.",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("headNormal", Grid.headNormal),
        ("headBlink", Grid.headBlink),
        ("headHiss", Grid.headHiss),
        ("headYawn", Grid.headYawn),
        ("headContent", Grid.headContent),
        ("coil", Grid.coil),
        ("neck", Grid.neck),
        ("bulge", Grid.bulge),
        ("rattle", Grid.rattle),
        ("tongue", Grid.tongue),
        ("egg", Grid.egg),
    ]

    // MARK: Sprites

    enum Head: CaseIterable {
        case normal, blink, hiss, yawn, content

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        private static let sprites = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, SnakeSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .normal: Grid.headNormal
            case .blink: Grid.headBlink
            case .hiss: Grid.headHiss
            case .yawn: Grid.headYawn
            case .content: Grid.headContent
            }
        }
    }

    private enum Part {
        static let coil = sprite(Grid.coil)
        static let neck = sprite(Grid.neck)
        static let bulge = sprite(Grid.bulge)
        static let rattle = sprite(Grid.rattle)
        static let tongue = sprite(Grid.tongue).outlined(with: SheepSprites.outline)
        static let egg = sprite(Grid.egg)
        /// The lower rows of the egg, coming in at the top edge.
        static let eggComingIn = sprite(Array(Grid.egg.suffix(2)))
    }

    // MARK: Frames

    /// The snake's layers, back to front. `raised` lifts the head on a longer neck, `rattle` moves the rattle right
    /// (shaking it), `dy` moves the whole snake (negative is up) and `headDY` only the head, without a neck below it.
    static func snake(
        head: Head = .normal, tongue: Bool = false, raised: Int = 0, rattle: Int = 0, dy: Int = 0, headDY: Int = 0
    ) -> [SpriteLayer] {
        let headY = -raised + headDY + dy
        return [layer(Part.coil, 0, 7 + dy), layer(Part.rattle, 15 + rattle, 3 + dy)]
            + (0..<raised).map { layer(Part.neck, 10, 6 - $0 + dy) }
            + (tongue ? [layer(Part.tongue, 0, headY + 3)] : [])
            + [layer(head.sprite, 4, headY)]
    }

    /// A sprite at a position within the snake (`snakeX`, `snakeY`).
    private static func layer(_ sprite: PixelSprite, _ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: sprite, x: snakeX + x, y: snakeY + y)
    }

    /// How high the head is raised while the snake swallows eggs or hisses.
    private static let reared = 2

    /// Swallowing eggs: an egg drops in at the top edge in front of the raised head, the snake catches it in its open
    /// mouth, and a bulge slides down its neck into the coil. `step` is the frame of the cycle (0 to 7).
    private static func swallowing(_ step: Int) -> [SpriteLayer] {
        switch step {
        case 0: [SpriteLayer(sprite: Part.eggComingIn, x: 2, y: 0)] + snake(raised: reared)
        case 1: [egg(1)] + snake(raised: reared)
        case 2: [egg(4)] + snake(head: .hiss, raised: reared)
        case 3: [egg(7)] + snake(head: .hiss, raised: reared)
        case 4, 5, 6: snake(head: step == 4 ? .blink : .normal, raised: reared) + [layer(Part.bulge, 9, step)]
        default: snake(raised: reared)
        }
    }

    private static func egg(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Part.egg, x: 2, y: y)
    }

    private static let checkBubble = SpriteLayer(sprite: SheepSprites.Effect.checkBubble, x: 0, y: 0)
    private static let exclamation = SpriteLayer(sprite: SheepSprites.Effect.exclamation, x: 1, y: 0)
    private static let asleep = snake(head: .blink, headDY: 2)
    private static let smallZ = SpriteLayer(sprite: SheepSprites.Effect.smallZ, x: 10, y: 5)
    private static let largeZ = SpriteLayer(sprite: SheepSprites.Effect.largeZ, x: 14, y: 1)
    private static let smallDust = SpriteLayer(sprite: SheepSprites.Effect.smallDust, x: 18, y: 17)

    private static func smallHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.smallHeart, x: 2, y: y)
    }

    private static func largeHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.largeHeart, x: 1, y: y)
    }

    private static func question(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.question, x: 0, y: y)
    }

    private static func frame(
        _ milliseconds: Int, _ layers: [SpriteLayer], opacity: Double = 1
    ) -> AnimationFrame {
        AnimationFrame(sprite: SpriteFrame(layers: layers, opacity: opacity), duration: .milliseconds(milliseconds))
    }

    // MARK: Clips

    // Keep every clip short (at most 1.6 s): a clip always plays to its end before the state machine switches.

    private static func clip(_ id: ClipID) -> AnimationClip {
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
            frame(1_000, snake())
        ])
        static let idleBlink = AnimationClip([
            frame(150, snake(head: .blink)),
            frame(250, snake()),
        ])
        /// Flicking its tongue, twice.
        static let idleLook = AnimationClip([
            frame(150, snake(tongue: true)),
            frame(150, snake()),
            frame(150, snake(tongue: true)),
            frame(550, snake()),
        ])
        /// The head resting on the coil.
        static let sleeping = AnimationClip([
            frame(700, asleep + [smallZ]),
            frame(700, asleep + [smallZ, largeZ]),
        ])
        static let working = AnimationClip((0..<8).map { step in frame(150, swallowing(step)) })
        /// Rearing up, hissing and rattling.
        static let blocked = AnimationClip([
            frame(150, snake(head: .hiss, raised: reared) + [exclamation]),
            frame(150, snake(head: .hiss, raised: reared, rattle: 1) + [exclamation]),
            frame(150, snake(head: .hiss, raised: reared)),
            frame(150, snake(head: .hiss, raised: reared, rattle: 1)),
            frame(150, snake(raised: reared) + [exclamation]),
            frame(150, snake(raised: reared, rattle: 1) + [exclamation]),
            frame(300, snake(raised: reared)),
        ])
        /// A hop of the whole coil, like a spring.
        static let doneJump = AnimationClip([
            frame(150, snake(tongue: true) + [checkBubble]),
            frame(120, snake(dy: -1) + [checkBubble]),
            frame(120, snake(dy: -2) + [checkBubble]),
            frame(120, snake(dy: -1) + [checkBubble]),
            frame(290, snake(head: .blink) + [checkBubble]),
        ])
        /// Flicking its tongue and shaking the rattle, pleased.
        static let doneHold = AnimationClip([
            frame(250, snake(tongue: true) + [checkBubble]),
            frame(250, snake(rattle: 1) + [checkBubble]),
            frame(250, snake(tongue: true) + [checkBubble]),
            frame(250, snake(rattle: 1) + [checkBubble]),
        ])
        /// Lowering its head, then tasting the air.
        static let unknown = AnimationClip([
            frame(700, snake(headDY: 1) + [question(1)], opacity: BuddyCanvas.unknownOpacity),
            frame(900, snake(tongue: true) + [question(0)], opacity: BuddyCanvas.unknownOpacity),
        ])

        // Still poses: one picture per state that still shows the state's sign, a frame of its clip.
        static let idleStill = AnimationClip.still(idleRest.frames[0].sprite)
        static let sleepingStill = AnimationClip.still(sleeping.frames[1].sprite)
        static let workingStill = AnimationClip.still(working.frames[5].sprite)
        static let blockedStill = AnimationClip.still(blocked.frames[0].sprite)
        static let doneStill = AnimationClip.still(doneHold.frames[0].sprite)
        static let unknownStill = AnimationClip.still(unknown.frames[1].sprite)
    }

    // MARK: Escape

    private static func escapeClip(_ id: EscapeClipID) -> AnimationClip {
        switch id {
        case .startle: Escape.startle
        case .yawn: Escape.yawn
        case .turn: Escape.turn
        case .run: Escape.run
        case .walk: Escape.walk
        case .arrive: Escape.arrive
        }
    }

    /// Clips of leaving the screen and of the return (`EscapeClipID`).
    private enum Escape {
        /// A startled hop with a hiss before springing away.
        static let startle = AnimationClip([
            frame(120, snake(head: .hiss, rattle: 1)),
            frame(100, snake(head: .hiss, dy: -2)),
            frame(100, snake(head: .hiss, rattle: 1, dy: -3)),
            frame(100, snake(dy: -2)),
            frame(80, snake()),
        ])
        /// A big yawn with the head raised before hopping off.
        static let yawn = AnimationClip([
            frame(200, snake()),
            frame(150, snake(head: .blink, raised: 1)),
            frame(600, snake(head: .yawn, raised: 1)),
            frame(200, snake(head: .blink)),
            frame(200, snake()),
        ])
        /// Lying still for a moment, shown mirrored when the snake turns around.
        static let turn = AnimationClip([
            frame(100, snake())
        ])
        /// Springing along in hops with the tongue out, looped while the panel moves.
        static let run = AnimationClip([
            frame(80, [smallDust] + snake(tongue: true)),
            frame(80, snake(tongue: true, dy: -2)),
            frame(80, snake(tongue: true, dy: -3)),
            frame(80, snake(tongue: true, dy: -2)),
        ])
        /// Small, slow hops with the head hanging, looped while the panel moves.
        static let walk = AnimationClip([
            frame(180, snake(headDY: 1)),
            frame(180, snake(dy: -1, headDY: 1)),
            frame(180, snake(headDY: 1)),
            frame(180, snake(head: .blink, headDY: 1)),
        ])
        /// Catching breath after coming back.
        static let arrive = AnimationClip([
            frame(150, snake(tongue: true, rattle: 1)),
            frame(150, snake()),
            frame(200, snake(tongue: true)),
        ])
    }

    // MARK: Petting

    /// The reaction to a click: the snake closes its eyes and blushes, shakes its rattle, a heart rises and the coil
    /// gives a small happy hop.
    private static let petted = AnimationClip([
        frame(120, snake(head: .content, headDY: 1)),
        frame(160, snake(head: .content, rattle: 1) + [smallHeart(3)]),
        frame(160, snake(head: .content, headDY: 1) + [smallHeart(2)]),
        frame(160, snake(head: .content, rattle: 1) + [largeHeart(1)]),
        frame(160, snake(head: .content, headDY: 1) + [largeHeart(0)]),
        frame(120, snake(head: .content, rattle: 1, dy: -1) + [largeHeart(0)]),
        frame(200, snake(head: .content) + [largeHeart(0)]),
        frame(200, snake()),
    ])

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
