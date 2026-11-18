// All pixel data of the dino lives in this file: the palette, the grids, how they are composed into frames, and the
// frame timing of every animation clip. A teal stegosaurus with four plates on its arched back and spikes at the tip of
// its tail; while agents work its plates light up one after another from the neck to the tail like a progress bar and
// go out again, and they turn red when it needs the user. The state's signs ("!", the ✔ bubble, "?", "zzz", hearts)
// are the sheep's (`SheepSprites.Effect`), so every buddy shows the same ones.

enum DinoSprites {
    static let buddy = Buddy(id: .dino, clips: ClipSet(clip), escape: ClipSet(escapeClip), petted: petted)

    /// Top-left corner of the dino on the canvas when standing: 22 × 11 pixels, the feet on the bottom row.
    static let dinoX = 0
    static let dinoY = 9
    /// Top-left corner of the head within the dino.
    static let headX = 0
    static let headY = 4

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": SheepSprites.outline,  // outline, eye
        "G": PixelColor(red: 0x5F, green: 0xB0, blue: 0x8E),  // skin
        "g": PixelColor(red: 0x3D, green: 0x80, blue: 0x68),  // spots on the back
        "Y": PixelColor(red: 0xE2, green: 0xE4, blue: 0xA8),  // belly
        "E": PixelColor(red: 0xFF, green: 0xFF, blue: 0xFF),  // eye glint
        "B": PixelColor(red: 0xF2, green: 0xE6, blue: 0xC8),  // tail spikes
        "P": SheepSprites.palette["P"]!,  // open mouth, cheek
        "K": Glow.dim.color,  // plates, recolored per `Glow`
    ]

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The dino is drawn back to front: the plates, the body, the head. Body variants differ only in their legs
        // (the last two rows), head variants only in the eye or mouth row.

        private static let body = [
            "..................O.O.",
            ".......OOOOOOOO..OBOBO",
            ".....OOGGgGGgGGOOOBOBO",
            "....OGGGGGGGGGGGGGGGGO",
            "..OOGGGGGGGGGGGGGGGOO.",
            "..OGGGGGGGGGGGGGGOO...",
            "...OGGYYYYYYYYYGGO....",
            "....OOYYYYYYYYGGO.....",
        ]
        /// The bottom of the belly with the top of the legs.
        private static let hips = ".....OGGOOOOOOGGO....."

        static let bodyStand = body + [hips, ".....OGGO....OGGO.....", ".....OOOO....OOOO....."]
        /// Front leg forward, hind leg back.
        static let bodyTrotA = body + [hips, "....OGGO......OGGO....", "....OOOO......OOOO...."]
        /// Legs under the belly.
        static let bodyTrotB = body + [hips, "......OGGO..OGGO......", "......OOOO..OOOO......"]
        /// Legs tucked in, for jumps.
        static let bodyJump = body + [hips, ".....OOOO....OOOO.....", "......................"]
        /// Lying down, two pixels lower, the legs folded under the belly.
        static let bodyLying = [String](repeating: "......................", count: 2) + body + [hips]

        private static func head(eye: String = "OGEOGG", mouth: String = "OGGGGO") -> [String] {
            ["..OO..", ".OGGGG", eye, mouth, ".OOOOO"]
        }

        static let headNormal = head()
        static let headBlink = head(eye: "OGOOGG")
        /// Eye turned forward.
        static let headLook = head(eye: "OEOGGG")
        /// Mouth open: roaring.
        static let headRoar = head(mouth: "OPPGGO")
        /// Eye closed and the mouth open, yawning.
        static let headYawn = head(eye: "OGOOGG", mouth: "OPPGGO")
        /// Eye closed and a blushing cheek, enjoying being petted.
        static let headContent = head(eye: "OGOOGG", mouth: "OGGPGO")

        /// Plates without outline; the outline is added when building the sprite, which recolors them per `Glow`.
        static let smallPlate = [
            "K",
            "K",
        ]
        static let largePlate = [
            ".K.",
            "KKK",
            "KKK",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("bodyStand", Grid.bodyStand),
        ("bodyTrotA", Grid.bodyTrotA),
        ("bodyTrotB", Grid.bodyTrotB),
        ("bodyJump", Grid.bodyJump),
        ("bodyLying", Grid.bodyLying),
        ("headNormal", Grid.headNormal),
        ("headBlink", Grid.headBlink),
        ("headLook", Grid.headLook),
        ("headRoar", Grid.headRoar),
        ("headYawn", Grid.headYawn),
        ("headContent", Grid.headContent),
        ("smallPlate", Grid.smallPlate),
        ("largePlate", Grid.largePlate),
    ]

    // MARK: Sprites

    enum Body: CaseIterable {
        case stand, trotA, trotB, jump, lying

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        /// How far the back, with the plates and the head, is below where it is when standing.
        var backDY: Int {
            self == .lying ? 2 : 0
        }

        private static let sprites = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, DinoSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .stand: Grid.bodyStand
            case .trotA: Grid.bodyTrotA
            case .trotB: Grid.bodyTrotB
            case .jump: Grid.bodyJump
            case .lying: Grid.bodyLying
            }
        }
    }

    enum Head: CaseIterable {
        case normal, blink, look, roar, yawn, content

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        private static let sprites = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, DinoSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .normal: Grid.headNormal
            case .blink: Grid.headBlink
            case .look: Grid.headLook
            case .roar: Grid.headRoar
            case .yawn: Grid.headYawn
            case .content: Grid.headContent
            }
        }
    }

    /// The color of a plate.
    enum Glow: CaseIterable {
        /// At rest: orange.
        case dim
        /// Lit up, while agents work and when they are done.
        case lit
        /// The brightest, when the plates flash.
        case bright
        /// Red like the "!", when the dino needs the user.
        case alarm

        var color: PixelColor {
            switch self {
            case .dim: PixelColor(red: 0xF0, green: 0x8A, blue: 0x3C)
            case .lit: PixelColor(red: 0xFF, green: 0xC8, blue: 0x3A)
            case .bright: PixelColor(red: 0xFF, green: 0xF2, blue: 0xA8)
            case .alarm: SheepSprites.palette["R"]!
            }
        }
    }

    /// A plate's grid in every glow, outlined.
    private static func plateSprites(_ grid: [String]) -> [Glow: PixelSprite] {
        Dictionary(
            uniqueKeysWithValues: Glow.allCases.map { glow in
                let colors = palette.merging(["K": glow.color]) { $1 }
                return (glow, PixelSprite(rows: grid, palette: colors).outlined(with: SheepSprites.outline))
            })
    }

    private static let smallPlate = plateSprites(Grid.smallPlate)
    private static let largePlate = plateSprites(Grid.largePlate)

    /// The plates from the neck to the tail: their sprites and the top-left corner of the outline within the dino.
    private static let plates: [(sprites: [Glow: PixelSprite], x: Int, y: Int)] = [
        (smallPlate, 4, -1), (largePlate, 6, -3), (largePlate, 10, -3), (smallPlate, 14, -1),
    ]

    // MARK: Frames

    /// Every plate in one glow.
    private static func all(_ glow: Glow) -> [Glow] {
        Array(repeating: glow, count: plates.count)
    }

    /// The plates at rest, lit up, flashing and asking for help.
    private static let dim = all(.dim)
    private static let lit = all(.lit)
    private static let bright = all(.bright)
    private static let alarm = all(.alarm)

    /// The dino's layers, back to front: the plates (`glow` from the neck to the tail), the body, the head. `dy` moves
    /// the whole dino (negative is up), `headDY` only the head.
    static func dino(
        body: Body = .stand, head: Head = .normal, plates glow: [Glow] = dim, dy: Int = 0, headDY: Int = 0
    ) -> [SpriteLayer] {
        let backY = dinoY + body.backDY + dy
        let plateLayers = zip(plates, glow).map { plate, glow in
            SpriteLayer(sprite: plate.sprites[glow]!, x: dinoX + plate.x, y: backY + plate.y)
        }
        return plateLayers + [
            SpriteLayer(sprite: body.sprite, x: dinoX, y: dinoY + dy),
            SpriteLayer(sprite: head.sprite, x: dinoX + headX, y: backY + headY + headDY),
        ]
    }

    /// The plates lighting up from the neck to the tail like a progress bar, then going out in the same order, so the
    /// loop never jumps: `step` 0 to `progressSteps - 1`.
    private static func progress(_ step: Int) -> [Glow] {
        plates.indices.map { (step <= plates.count ? $0 < step : $0 >= step - plates.count) ? .lit : .dim }
    }

    private static let progressSteps = 2 * plates.count

    private static let checkBubble = SpriteLayer(sprite: SheepSprites.Effect.checkBubble, x: 0, y: 0)
    private static let exclamation = SpriteLayer(sprite: SheepSprites.Effect.exclamation, x: 1, y: 0)
    private static let asleep = dino(body: .lying, head: .blink)
    private static let smallZ = SpriteLayer(sprite: SheepSprites.Effect.smallZ, x: 2, y: 3)
    private static let largeZ = SpriteLayer(sprite: SheepSprites.Effect.largeZ, x: 7, y: 0)
    private static let largeDust = SpriteLayer(sprite: SheepSprites.Effect.largeDust, x: 17, y: 16)
    private static let smallDust = SpriteLayer(sprite: SheepSprites.Effect.smallDust, x: 18, y: 17)

    private static func smallHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.smallHeart, x: 0, y: y)
    }

    private static func largeHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.largeHeart, x: 0, y: y)
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
            frame(1_000, dino())
        ])
        static let idleBlink = AnimationClip([
            frame(150, dino(head: .blink)),
            frame(250, dino()),
        ])
        static let idleLook = AnimationClip([
            frame(700, dino(head: .look, headDY: -1)),
            frame(300, dino()),
        ])
        /// Lying with the head on the ground.
        static let sleeping = AnimationClip([
            frame(700, asleep + [smallZ]),
            frame(700, asleep + [smallZ, largeZ]),
        ])
        /// Trotting in place while the plates light up one after another and go out again.
        static let working = AnimationClip(
            (0..<progressSteps).map { step in
                let legs: [Body] = [.trotA, .stand, .trotB, .stand]
                return frame(150, dino(body: legs[step % 4], plates: progress(step)))
            })
        /// Roaring and jumping with red plates.
        static let blocked = AnimationClip([
            frame(150, dino(head: .roar, plates: alarm) + [exclamation]),
            frame(120, dino(body: .jump, head: .roar, plates: alarm, dy: -2) + [exclamation]),
            frame(120, dino(body: .jump, plates: alarm, dy: -3)),
            frame(120, dino(body: .jump, dy: -2)),
            frame(150, dino(plates: alarm) + [exclamation]),
            frame(340, dino()),
        ])
        /// A happy jump with every plate lit, a full progress bar.
        static let doneJump = AnimationClip([
            frame(150, dino(plates: lit) + [checkBubble]),
            frame(120, dino(body: .jump, plates: lit, dy: -2) + [checkBubble]),
            frame(120, dino(body: .jump, plates: bright, dy: -3) + [checkBubble]),
            frame(120, dino(body: .jump, plates: lit, dy: -2) + [checkBubble]),
            frame(290, dino(head: .blink, plates: lit) + [checkBubble]),
        ])
        static let doneHold = AnimationClip([
            frame(600, dino(head: .blink, plates: lit) + [checkBubble]),
            frame(400, dino(plates: lit) + [checkBubble]),
        ])
        /// Lowering its head, then looking up.
        static let unknown = AnimationClip([
            frame(800, dino(headDY: 1) + [question(1)], opacity: BuddyCanvas.unknownOpacity),
            frame(800, dino(head: .look, headDY: -1) + [question(0)], opacity: BuddyCanvas.unknownOpacity),
        ])

        // Still poses: one picture per state that still shows the state's sign, a frame of its clip.
        static let idleStill = AnimationClip.still(idleRest.frames[0].sprite)
        static let sleepingStill = AnimationClip.still(sleeping.frames[1].sprite)
        /// Half of the plates lit: work in progress.
        static let workingStill = AnimationClip.still(working.frames[2].sprite)
        static let blockedStill = AnimationClip.still(blocked.frames[0].sprite)
        static let doneStill = AnimationClip.still(doneHold.frames[1].sprite)
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
        /// A startled hop with a roar and flashing plates before running away.
        static let startle = AnimationClip([
            frame(120, dino(head: .roar, plates: bright)),
            frame(100, dino(body: .jump, head: .roar, plates: bright, dy: -2)),
            frame(100, dino(body: .jump, head: .roar, dy: -3)),
            frame(100, dino(body: .jump, dy: -2)),
            frame(80, dino()),
        ])
        /// A slow yawn with the head raised before wandering off.
        static let yawn = AnimationClip([
            frame(200, dino()),
            frame(150, dino(head: .blink, headDY: -1)),
            frame(600, dino(head: .yawn, headDY: -1)),
            frame(200, dino(head: .blink)),
            frame(200, dino()),
        ])
        /// Standing still for a moment, shown mirrored when the dino turns around.
        static let turn = AnimationClip([
            frame(100, dino())
        ])
        /// Running, looped while the panel moves.
        static let run = AnimationClip([
            frame(80, dino(body: .trotA) + [largeDust]),
            frame(80, dino(body: .jump, dy: -1) + [smallDust]),
            frame(80, dino(body: .trotB)),
            frame(80, dino(body: .jump, dy: -1)),
        ])
        /// A slow walk with the head hanging and bobbing, looped while the panel moves.
        static let walk = AnimationClip([
            frame(180, dino(body: .trotA, headDY: 1)),
            frame(180, dino()),
            frame(180, dino(body: .trotB, headDY: 1)),
            frame(180, dino()),
        ])
        /// Catching breath after coming back.
        static let arrive = AnimationClip([
            frame(150, dino(head: .roar)),
            frame(150, dino(head: .blink)),
            frame(200, dino()),
        ])
    }

    // MARK: Petting

    /// The reaction to a click: the dino closes its eye and blushes, its plates glow, a heart rises and it gives a
    /// small happy hop.
    private static let petted = AnimationClip([
        frame(120, dino(head: .content, headDY: 1)),
        frame(160, dino(head: .content, plates: lit) + [smallHeart(7)]),
        frame(160, dino(head: .content, plates: lit, headDY: 1) + [smallHeart(6)]),
        frame(160, dino(head: .content, plates: lit) + [largeHeart(4)]),
        frame(160, dino(head: .content, plates: lit, headDY: 1) + [largeHeart(3)]),
        frame(120, dino(body: .jump, head: .content, plates: lit, dy: -1) + [largeHeart(3)]),
        frame(200, dino(head: .content, plates: lit) + [largeHeart(3)]),
        frame(200, dino()),
    ])

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
