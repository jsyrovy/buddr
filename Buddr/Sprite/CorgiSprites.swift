// All pixel data of the corgi lives in this file: the palette, the grids, how they are composed into frames, and the
// frame timing of every animation clip. An orange and white corgi with big ears and a big head turned to the viewer;
// it digs a hole while agents work and tilts its head when it doesn't know what is going on. The state's signs ("!",
// the ✔ bubble, "?", "zzz", hearts) are the sheep's (`SheepSprites.Effect`), so every buddy shows the same ones.

enum CorgiSprites {
    static let buddy = Buddy(id: .corgi, clips: ClipSet(clip), escape: ClipSet(escapeClip), petted: petted)

    /// Top-left corner of the corgi on the canvas when standing: 20 × 14 pixels, its paws on the bottom row.
    static let corgiX = 1
    static let corgiY = 6

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": SheepSprites.outline,  // outline, eyes, nose
        "C": PixelColor(red: 0xE8, green: 0x92, blue: 0x3E),  // orange fur
        "c": PixelColor(red: 0xB8, green: 0x68, blue: 0x2C),  // orange fur shade
        "W": PixelColor(red: 0xFA, green: 0xF5, blue: 0xEB),  // white fur
        "w": PixelColor(red: 0xDA, green: 0xD0, blue: 0xC0),  // white fur shade
        "E": PixelColor(red: 0xFF, green: 0xFF, blue: 0xFF),  // eye glints
        "P": SheepSprites.palette["P"]!,  // ears, tongue, open mouth, cheeks
        "D": PixelColor(red: 0xA8, green: 0x74, blue: 0x43),  // dirt
        "d": PixelColor(red: 0xD4, green: 0xA2, blue: 0x6C),  // dirt, lit
    ]

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The corgi is drawn back to front: body, tail, head. Every part has its place in the corgi
        // (`corgi(body:head:tail:dy:headDY:)`); variants of a part differ only in a row or two.

        private static let upEars = [
            ".O......O.",
            "OPO....OPO",
            "OPCO..OCPO",
            "OPPCOOCPPO",
        ]
        /// The ear at the back folded down for a moment.
        private static let flickedEars = [
            ".O........",
            "OPO.......",
            "OPCO..OOOO",
            "OPPCOOCCCO",
        ]
        private static let openEyes = ["OCEOWWEOCO", "OCOOWWOOCO"]
        private static let closedEyes = ["OCCCWWCCCO", "OCOOWWOOCO"]
        private static let cheeks = "OCCWWWWCCO"
        private static let blushingCheeks = "OPCWWWWCPO"
        private static let closedMouth = ["..OWWWWO.."]

        /// The head turned to the viewer, its chin resting on the chest; the muzzle (from the nose row down) is the
        /// only part below the cheeks.
        private static func head(
            ears: [String] = upEars, eyes: [String] = openEyes, cheeks: String = cheeks,
            mouth: [String] = closedMouth
        ) -> [String] {
            ears + eyes + [cheeks, ".OWWOOWWO."] + mouth
        }

        static let headNormal = head()
        static let headBlink = head(eyes: closedEyes)
        static let headFlick = head(ears: flickedEars)
        /// Mouth open, barking.
        static let headBark = head(mouth: ["..OPPPPO..", "...OOOO..."])
        /// Panting with the tongue out.
        static let headPant = head(mouth: ["..OWPPWO..", "...OPPO...", "....OO...."])
        /// Eyes closed, cheeks blushing and the tongue out, enjoying being petted.
        static let headContent = head(
            eyes: closedEyes, cheeks: blushingCheeks, mouth: ["..OWPPWO..", "...OPPO...", "....OO...."])
        /// Eyes closed and the mouth wide open, yawning.
        static let headYawn = head(eyes: closedEyes, mouth: ["..OPPPPO..", "..OPPPPO..", "...OOOO..."])
        static let headAsleep = head(eyes: closedEyes)
        /// The head tilted, its right side up: puzzled. Drawn one pixel left of and above the others.
        static let headTilt = [
            ".......O...",
            "......OPO..",
            ".O...OCPO..",
            "OPO.OCCPPO.",
            "OPPCOCCEOCO",
            "OCCCCWWOOCO",
            "OCCEOWWWCCO",
            ".OCOOWWWWCO",
            ".OWWWWOOWO.",
            "...OWWWWO..",
        ]

        private static let torso = [
            ".......OOOOOOOO...",
            ".....OWCCCCCCCCCO.",
            ".OWWWWWWCCCCCCCCCO",
            ".OWWWWWCCCCCCCCCcO",
            ".OWWWWWCCCCCCCCccO",
            ".OWWWWWWWWWWWWWwwO",
        ]
        private static let belly = ".OWWOOOOOOOOOOOWWO"

        static let bodyStand = torso + [belly, ".OWWO........OWWO.", ".OOOO........OOOO."]
        /// Front paw forward, back paw back.
        static let bodyTrotA = torso + [belly, "OWWO..........OWWO", "OOOO..........OOOO"]
        /// Front paw back, back paw forward.
        static let bodyTrotB = torso + [belly, "..OWWO......OWWO..", "..OOOO......OOOO.."]
        /// Paws drawn in, for jumps.
        static let bodyJump = torso + [belly, ".OOOO........OOOO.", ".................."]
        /// The front paw raised, scraping the ground.
        static let bodyDig = torso + [belly, ".OOOO........OWWO.", ".............OOOO."]
        /// Lying down, two pixels lower, paws folded.
        static let bodyLying = ["..................", ".................."] + torso + [".OOOOOOOOOOOOOOOOO"]

        static let tailUp = [
            "..OO.",
            ".OCCO",
        ]
        static let tailLeft = [
            ".OO..",
            ".OCO.",
            ".OCCO",
        ]
        static let tailRight = [
            "...OO",
            "..OCO",
            ".OCCO",
        ]
        /// Hanging, for a slow walk.
        static let tailDown = [
            ".OOOO"
        ]

        // Dirt without outline; the outline is added when building the sprite.

        static let smallClod = [
            "D"
        ]
        static let largeClod = [
            "dD",
            "DD",
        ]
        /// The heap the clods land on, behind the back paws.
        static let heap = [
            ".d.",
            "dDD",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("headNormal", Grid.headNormal),
        ("headBlink", Grid.headBlink),
        ("headFlick", Grid.headFlick),
        ("headBark", Grid.headBark),
        ("headPant", Grid.headPant),
        ("headContent", Grid.headContent),
        ("headYawn", Grid.headYawn),
        ("headAsleep", Grid.headAsleep),
        ("headTilt", Grid.headTilt),
        ("bodyStand", Grid.bodyStand),
        ("bodyTrotA", Grid.bodyTrotA),
        ("bodyTrotB", Grid.bodyTrotB),
        ("bodyJump", Grid.bodyJump),
        ("bodyDig", Grid.bodyDig),
        ("bodyLying", Grid.bodyLying),
        ("tailUp", Grid.tailUp),
        ("tailLeft", Grid.tailLeft),
        ("tailRight", Grid.tailRight),
        ("tailDown", Grid.tailDown),
        ("smallClod", Grid.smallClod),
        ("largeClod", Grid.largeClod),
        ("heap", Grid.heap),
    ]

    // MARK: Sprites

    enum Head: CaseIterable {
        case normal, blink, flick, bark, pant, content, yawn, asleep, tilt

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        /// Where the head sits relative to the others: the tilted one is larger.
        var offset: (x: Int, y: Int) {
            self == .tilt ? (-1, -1) : (0, 0)
        }

        private static let sprites = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, CorgiSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .normal: Grid.headNormal
            case .blink: Grid.headBlink
            case .flick: Grid.headFlick
            case .bark: Grid.headBark
            case .pant: Grid.headPant
            case .content: Grid.headContent
            case .yawn: Grid.headYawn
            case .asleep: Grid.headAsleep
            case .tilt: Grid.headTilt
            }
        }
    }

    enum Body: CaseIterable {
        case stand, trotA, trotB, jump, dig, lying

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        /// How far the back, and the tail on it, is below where it is when standing.
        var backDY: Int {
            self == .lying ? 2 : 0
        }

        private static let sprites = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, CorgiSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .stand: Grid.bodyStand
            case .trotA: Grid.bodyTrotA
            case .trotB: Grid.bodyTrotB
            case .jump: Grid.bodyJump
            case .dig: Grid.bodyDig
            case .lying: Grid.bodyLying
            }
        }
    }

    enum Tail: CaseIterable {
        case up, left, right, down

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        private static let sprites = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, CorgiSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .up: Grid.tailUp
            case .left: Grid.tailLeft
            case .right: Grid.tailRight
            case .down: Grid.tailDown
            }
        }
    }

    private enum Part {
        static let smallClod = sprite(Grid.smallClod).outlined(with: SheepSprites.outline)
        static let largeClod = sprite(Grid.largeClod).outlined(with: SheepSprites.outline)
        static let heap = sprite(Grid.heap).outlined(with: SheepSprites.outline)
    }

    // MARK: Frames

    /// The corgi's layers, back to front. `dy` moves the whole corgi (negative is up), `headDY` only the head.
    static func corgi(
        body: Body = .stand, head: Head = .normal, tail: Tail = .up, dy: Int = 0, headDY: Int = 0
    ) -> [SpriteLayer] {
        [
            layer(body.sprite, 1, 5 + dy),
            layer(tail.sprite, 14, 6 - tail.sprite.height + body.backDY + dy),
            layer(head.sprite, head.offset.x, head.offset.y + dy + headDY),
        ]
    }

    /// A sprite at a position within the corgi (`corgiX`, `corgiY`).
    private static func layer(_ sprite: PixelSprite, _ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: sprite, x: corgiX + x, y: corgiY + y)
    }

    /// Digging: the head down, the front paw scraping, clods of dirt thrown up from under the corgi in an arc over
    /// its back onto a heap behind it. `step` is the frame of the cycle (0 to 3); the two clods follow the same path half a cycle
    /// apart.
    private static func digging(_ step: Int) -> [SpriteLayer] {
        let path = [(10, 9), (13, 5), (16, 4), (18, 10)]
        let large = path[step]
        let small = path[(step + 2) % path.count]
        return [
            SpriteLayer(sprite: Part.heap, x: 17, y: 16),
            SpriteLayer(sprite: Part.largeClod, x: large.0, y: large.1),
            SpriteLayer(sprite: Part.smallClod, x: small.0, y: small.1),
        ] + corgi(body: step.isMultiple(of: 2) ? .dig : .stand, tail: step < 2 ? .left : .right, headDY: 1)
    }

    private static let checkBubble = SpriteLayer(sprite: SheepSprites.Effect.checkBubble, x: 0, y: 0)
    private static let exclamation = SpriteLayer(sprite: SheepSprites.Effect.exclamation, x: 1, y: 0)
    private static let asleep = corgi(body: .lying, head: .asleep, tail: .down, headDY: 3)
    private static let smallZ = SpriteLayer(sprite: SheepSprites.Effect.smallZ, x: 11, y: 5)
    private static let largeZ = SpriteLayer(sprite: SheepSprites.Effect.largeZ, x: 15, y: 1)
    private static let smallDust = SpriteLayer(sprite: SheepSprites.Effect.smallDust, x: 18, y: 17)

    private static func smallHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.smallHeart, x: 3, y: y)
    }

    private static func largeHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.largeHeart, x: 2, y: y)
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
        /// Standing, wagging its tail slowly.
        static let idleRest = AnimationClip([
            frame(300, corgi()),
            frame(200, corgi(tail: .left)),
            frame(300, corgi()),
            frame(200, corgi(tail: .right)),
        ])
        static let idleBlink = AnimationClip([
            frame(150, corgi(head: .blink)),
            frame(250, corgi()),
        ])
        /// An ear twitching, twice.
        static let idleLook = AnimationClip([
            frame(150, corgi(head: .flick)),
            frame(150, corgi()),
            frame(150, corgi(head: .flick)),
            frame(550, corgi()),
        ])
        static let sleeping = AnimationClip([
            frame(700, asleep + [smallZ]),
            frame(700, asleep + [smallZ, largeZ]),
        ])
        static let working = AnimationClip((0..<4).map { step in frame(150, digging(step)) })
        static let blocked = AnimationClip([
            frame(150, corgi(head: .bark, tail: .left) + [exclamation]),
            frame(120, corgi(body: .jump, head: .bark, tail: .right, dy: -2) + [exclamation]),
            frame(120, corgi(body: .jump, tail: .left, dy: -3)),
            frame(120, corgi(body: .jump, tail: .right, dy: -2)),
            frame(150, corgi(head: .bark, tail: .left) + [exclamation]),
            frame(340, corgi(tail: .right)),
        ])
        static let doneJump = AnimationClip([
            frame(150, corgi(head: .pant, tail: .left) + [checkBubble]),
            frame(120, corgi(body: .jump, head: .pant, tail: .right, dy: -2) + [checkBubble]),
            frame(120, corgi(body: .jump, head: .pant, tail: .left, dy: -3) + [checkBubble]),
            frame(120, corgi(body: .jump, head: .pant, tail: .right, dy: -2) + [checkBubble]),
            frame(290, corgi(head: .blink, tail: .left) + [checkBubble]),
        ])
        /// Panting and wagging.
        static let doneHold = AnimationClip([
            frame(250, corgi(head: .pant, tail: .left) + [checkBubble]),
            frame(250, corgi(head: .pant, tail: .right) + [checkBubble]),
            frame(250, corgi(head: .pant, tail: .left) + [checkBubble]),
            frame(250, corgi(head: .pant, tail: .right) + [checkBubble]),
        ])
        /// Looking, then tilting the head, puzzled.
        static let unknown = AnimationClip([
            frame(700, corgi() + [question(1)], opacity: BuddyCanvas.unknownOpacity),
            frame(900, corgi(head: .tilt) + [question(0)], opacity: BuddyCanvas.unknownOpacity),
        ])

        // Still poses: one picture per state that still shows the state's sign, a frame of its clip.
        static let idleStill = AnimationClip.still(idleRest.frames[0].sprite)
        static let sleepingStill = AnimationClip.still(sleeping.frames[1].sprite)
        static let workingStill = AnimationClip.still(working.frames[1].sprite)
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
        /// A startled hop with a yelp before running away.
        static let startle = AnimationClip([
            frame(120, corgi(head: .bark)),
            frame(100, corgi(body: .jump, head: .bark, dy: -2)),
            frame(100, corgi(body: .jump, head: .bark, dy: -3)),
            frame(100, corgi(body: .jump, dy: -2)),
            frame(80, corgi()),
        ])
        /// A big yawn with the head raised before trotting off.
        static let yawn = AnimationClip([
            frame(200, corgi()),
            frame(150, corgi(head: .blink, headDY: -1)),
            frame(600, corgi(head: .yawn, headDY: -1)),
            frame(200, corgi(head: .blink)),
            frame(200, corgi()),
        ])
        /// Standing still for a moment, shown mirrored when the corgi turns around.
        static let turn = AnimationClip([
            frame(100, corgi())
        ])
        /// Running with the tongue out, looped while the panel moves.
        static let run = AnimationClip([
            frame(80, corgi(body: .trotA, head: .pant, tail: .right) + [smallDust]),
            frame(80, corgi(body: .jump, head: .pant, tail: .up, dy: -1)),
            frame(80, corgi(body: .trotB, head: .pant, tail: .right)),
            frame(80, corgi(body: .jump, head: .pant, tail: .up, dy: -1)),
        ])
        /// A slow walk with the head and the tail hanging, looped while the panel moves.
        static let walk = AnimationClip([
            frame(180, corgi(body: .trotA, tail: .down, headDY: 1)),
            frame(180, corgi(tail: .down)),
            frame(180, corgi(body: .trotB, tail: .down, headDY: 1)),
            frame(180, corgi(tail: .down)),
        ])
        /// Catching breath after coming back.
        static let arrive = AnimationClip([
            frame(150, corgi(head: .pant, tail: .left)),
            frame(150, corgi(head: .pant, tail: .right)),
            frame(200, corgi()),
        ])
    }

    // MARK: Petting

    /// The reaction to a click: the corgi closes its eyes, blushes and pants, wags fast, a heart rises and it gives a
    /// small happy hop.
    private static let petted = AnimationClip([
        frame(120, corgi(head: .content, tail: .left, headDY: 1)),
        frame(160, corgi(head: .content, tail: .right) + [smallHeart(3)]),
        frame(160, corgi(head: .content, tail: .left, headDY: 1) + [smallHeart(2)]),
        frame(160, corgi(head: .content, tail: .right) + [largeHeart(1)]),
        frame(160, corgi(head: .content, tail: .left, headDY: 1) + [largeHeart(0)]),
        frame(120, corgi(body: .jump, head: .content, tail: .right, dy: -1) + [largeHeart(0)]),
        frame(200, corgi(head: .content, tail: .left) + [largeHeart(0)]),
        frame(200, corgi()),
    ])

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
