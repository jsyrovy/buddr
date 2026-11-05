// All pixel data of the rainbow cat lives in this file: the palette, the grids, how they are composed into frames, and
// the frame timing of every animation clip. A grey cat with a pop-tart body; it flies on a rainbow while agents work.
// The state's signs ("!", the ✔ bubble, "?", "zzz", hearts) are the sheep's (`SheepSprites.Effect`), so every buddy
// shows the same ones.

enum RainbowCatSprites {
    static let buddy = Buddy(id: .rainbowCat, clips: ClipSet(clip), escape: ClipSet(escapeClip), petted: petted)

    /// Top-left corner of the cat on the canvas when standing: 18 × 11 pixels, legs and chin on the bottom row.
    static let catX = 2
    static let catY = 9

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": SheepSprites.outline,  // outline, eyes, mouth
        "G": PixelColor(red: 0x9C, green: 0x9A, blue: 0xA0),  // fur
        "W": PixelColor(red: 0xFF, green: 0xFF, blue: 0xFF),  // stars
        "P": PixelColor(red: 0xFF, green: 0x9E, blue: 0xAE),  // cheeks
        "M": PixelColor(red: 0xC8, green: 0x32, blue: 0x4A),  // open mouth
        "T": PixelColor(red: 0xFF, green: 0xD3, blue: 0x9B),  // pop-tart crust
        "K": PixelColor(red: 0xFF, green: 0x9C, blue: 0xF0),  // frosting
        "S": PixelColor(red: 0xF0, green: 0x38, blue: 0x8C),  // sprinkles
        "r": PixelColor(red: 0xFF, green: 0x3B, blue: 0x3B),  // rainbow, top to bottom
        "o": PixelColor(red: 0xFF, green: 0x9A, blue: 0x1F),
        "y": PixelColor(red: 0xFF, green: 0xE8, blue: 0x1F),
        "l": PixelColor(red: 0x4C, green: 0xE0, blue: 0x1F),
        "b": PixelColor(red: 0x1F, green: 0x9C, blue: 0xFF),
        "v": PixelColor(red: 0x7A, green: 0x45, blue: 0xFF),
    ]

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The cat is drawn back to front: rainbow, tail, legs, pop-tart, head. Every part has its place in the cat
        // (`cat(legs:tail:head:dy:headDY:)`); variants of a part differ only in its pose.

        static let tart = [
            ".OOOOOOOO.",
            "OTTTTTTTTO",
            "OTKSKKKKTO",
            "OTKKKKSKTO",
            "OTKKSKKKTO",
            "OTKKKKKSTO",
            "OTKKKSKKTO",
            "OTTTTTTTTO",
            ".OOOOOOOO.",
        ]

        private static func head(
            eyes: [String] = ["OGOGGOGO", "OGOGGOGO"], mouth: [String] = ["OPGOOGPO", ".OGGGGO."]
        )
            -> [String]
        {
            [".O....O.", "OGO..OGO", "OGGOOGGO"] + eyes + mouth + ["..OOOO.."]
        }

        private static let closedEyes = ["OGGGGGGO", "OGOGGOGO"]
        private static let openMouth = ["OPOMMOPO", ".OOMMOO."]

        static let headNormal = head()
        static let headBlink = head(eyes: closedEyes)
        /// Eyes turned forward.
        static let headLook = head(eyes: ["OOGGOGGO", "OOGGOGGO"])
        /// Mouth open, meowing.
        static let headMeow = head(mouth: openMouth)
        /// Eyes closed and the cheeks blushing, enjoying being petted.
        static let headContent = head(eyes: closedEyes, mouth: ["OPPOOPPO", ".OGGGGO."])
        /// Eyes closed and the mouth wide open, yawning.
        static let headYawn = head(eyes: closedEyes, mouth: openMouth)

        static let tailUp = [
            "..O.",
            ".OGO",
            "OGO.",
            ".O..",
        ]
        static let tailDown = [
            ".O..",
            "OGO.",
            ".OGO",
            "..O.",
        ]

        static let legsStand = [
            ".OGGO..OGGO..",
            "..OO....OO...",
        ]
        /// Paws reaching forward, then back: paddling through the air.
        static let legsForward = [
            "OGGO..OGGO...",
            ".OO....OO....",
        ]
        static let legsBack = [
            "..OGGO..OGGO.",
            "...OO....OO..",
        ]
        /// Legs tucked in, for jumps.
        static let legsTucked = [
            "..OO....OO..."
        ]

        /// The rainbow behind the flying cat, its stripes waving up and down; no outline.
        static let rainbowA = [
            "..rrr...",
            "rrooorrr",
            "ooyyyooo",
            "yylllyyy",
            "llbbblll",
            "bbvvvbbb",
            "vv...vvv",
        ]
        static let rainbowB = [
            "rr...rrr",
            "oorrrooo",
            "yyoooyyy",
            "llyyylll",
            "bblllbbb",
            "vvbbbvvv",
            "..vvv...",
        ]

        static let largeStar = [
            "..O..",
            ".OWO.",
            "OWWWO",
            ".OWO.",
            "..O..",
        ]
        static let smallStar = [
            ".O.",
            "OWO",
            ".O.",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("tart", Grid.tart),
        ("headNormal", Grid.headNormal),
        ("headBlink", Grid.headBlink),
        ("headLook", Grid.headLook),
        ("headMeow", Grid.headMeow),
        ("headContent", Grid.headContent),
        ("headYawn", Grid.headYawn),
        ("tailUp", Grid.tailUp),
        ("tailDown", Grid.tailDown),
        ("legsStand", Grid.legsStand),
        ("legsForward", Grid.legsForward),
        ("legsBack", Grid.legsBack),
        ("legsTucked", Grid.legsTucked),
        ("rainbowA", Grid.rainbowA),
        ("rainbowB", Grid.rainbowB),
        ("largeStar", Grid.largeStar),
        ("smallStar", Grid.smallStar),
    ]

    // MARK: Sprites

    /// The cat's heads; like its other parts, each pose is built once (`Part`).
    enum Head: CaseIterable {
        case normal, blink, look, meow, content, yawn

        var sprite: PixelSprite {
            switch self {
            case .normal: Part.headNormal
            case .blink: Part.headBlink
            case .look: Part.headLook
            case .meow: Part.headMeow
            case .content: Part.headContent
            case .yawn: Part.headYawn
            }
        }
    }

    enum Legs {
        case stand, forward, back, tucked

        var sprite: PixelSprite {
            switch self {
            case .stand: Part.legsStand
            case .forward: Part.legsForward
            case .back: Part.legsBack
            case .tucked: Part.legsTucked
            }
        }
    }

    enum Tail {
        case up, down

        var sprite: PixelSprite {
            switch self {
            case .up: Part.tailUp
            case .down: Part.tailDown
            }
        }
    }

    enum Rainbow {
        case a, b

        var sprite: PixelSprite {
            switch self {
            case .a: Part.rainbowA
            case .b: Part.rainbowB
            }
        }
    }

    private enum Part {
        static let tart = sprite(Grid.tart)
        static let headNormal = sprite(Grid.headNormal)
        static let headBlink = sprite(Grid.headBlink)
        static let headLook = sprite(Grid.headLook)
        static let headMeow = sprite(Grid.headMeow)
        static let headContent = sprite(Grid.headContent)
        static let headYawn = sprite(Grid.headYawn)
        static let legsStand = sprite(Grid.legsStand)
        static let legsForward = sprite(Grid.legsForward)
        static let legsBack = sprite(Grid.legsBack)
        static let legsTucked = sprite(Grid.legsTucked)
        static let tailUp = sprite(Grid.tailUp)
        static let tailDown = sprite(Grid.tailDown)
        static let rainbowA = sprite(Grid.rainbowA)
        static let rainbowB = sprite(Grid.rainbowB)
        static let largeStar = sprite(Grid.largeStar)
        static let smallStar = sprite(Grid.smallStar)
    }

    // MARK: Frames

    /// The cat's layers, back to front. `legs` is `nil` while lying (tucked under the pop-tart); `rainbow` trails
    /// behind it while flying. `dy` moves the whole cat (negative is up), `headDY` only the head.
    static func cat(
        legs: Legs? = .stand, tail: Tail = .up, head: Head = .normal, rainbow: Rainbow? = nil, dy: Int = 0,
        headDY: Int = 0
    ) -> [SpriteLayer] {
        let tailY = tail == .up ? 2 : 4
        return [
            rainbow.map { layer($0.sprite, 12, 1 + dy) },
            layer(tail.sprite, 14, tailY + dy),
            legs.map { layer($0.sprite, 5, 9 + dy) },
            layer(Part.tart, 5, dy),
            layer(head.sprite, 0, 3 + dy + headDY),
        ].compactMap { $0 }
    }

    /// A sprite at a position within the cat (`catX`, `catY`).
    private static func layer(_ sprite: PixelSprite, _ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: sprite, x: catX + x, y: catY + y)
    }

    private static let checkBubble = SpriteLayer(sprite: SheepSprites.Effect.checkBubble, x: 0, y: 0)
    private static let exclamation = SpriteLayer(sprite: SheepSprites.Effect.exclamation, x: 1, y: 0)
    /// Lying: the pop-tart down on the ground, the head where it was (the chin already rests on the ground).
    private static let asleep = cat(legs: nil, tail: .down, head: .blink, dy: 2, headDY: -2)
    private static let smallZ = SpriteLayer(sprite: SheepSprites.Effect.smallZ, x: 9, y: 4)
    private static let largeZ = SpriteLayer(sprite: SheepSprites.Effect.largeZ, x: 13, y: 0)

    /// Stars twinkling around the flying cat, placed by their centers.
    private static func largeStar(_ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Part.largeStar, x: x - 2, y: y - 2)
    }

    private static func smallStar(_ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Part.smallStar, x: x - 1, y: y - 1)
    }

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

    // Keep every clip short (well under 1.5 s): a clip always plays to its end before the state machine switches.

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
            frame(1_000, cat())
        ])
        static let idleBlink = AnimationClip([
            frame(150, cat(head: .blink)),
            frame(250, cat()),
        ])
        static let idleLook = AnimationClip([
            frame(700, cat(tail: .down, head: .look, headDY: -1)),
            frame(300, cat()),
        ])
        static let sleeping = AnimationClip([
            frame(700, asleep + [smallZ]),
            frame(700, asleep + [smallZ, largeZ]),
        ])
        /// Flying on its rainbow: paddling, bobbing, wagging its tail, stars twinkling around.
        static let working = AnimationClip([
            frame(150, cat(legs: .forward, rainbow: .a) + [largeStar(18, 2)]),
            frame(150, cat(legs: .back, tail: .down, rainbow: .b, dy: -1) + [smallStar(18, 2), smallStar(14, 4)]),
            frame(150, cat(legs: .forward, rainbow: .a) + [largeStar(14, 4)]),
            frame(150, cat(legs: .back, tail: .down, rainbow: .b, dy: -1) + [smallStar(14, 4), smallStar(18, 2)]),
        ])
        static let blocked = AnimationClip([
            frame(150, cat(head: .meow) + [exclamation]),
            frame(120, cat(legs: .tucked, head: .meow, dy: -2) + [exclamation]),
            frame(120, cat(legs: .tucked, tail: .down, dy: -3)),
            frame(120, cat(legs: .tucked, dy: -2)),
            frame(150, cat() + [exclamation]),
            frame(340, cat()),
        ])
        static let doneJump = AnimationClip([
            frame(150, cat() + [checkBubble]),
            frame(120, cat(legs: .tucked, dy: -2) + [checkBubble]),
            frame(120, cat(legs: .tucked, tail: .down, dy: -3) + [checkBubble]),
            frame(120, cat(legs: .tucked, dy: -2) + [checkBubble]),
            frame(290, cat(head: .blink) + [checkBubble]),
        ])
        static let doneHold = AnimationClip([
            frame(600, cat(tail: .down, head: .blink) + [checkBubble]),
            frame(400, cat() + [checkBubble]),
        ])
        static let unknown = AnimationClip([
            frame(800, cat() + [question(1)], opacity: BuddyCanvas.unknownOpacity),
            frame(800, cat() + [question(0)], opacity: BuddyCanvas.unknownOpacity),
        ])

        // Still poses: one picture per state that still shows the state's sign, mostly a frame of its clip.
        static let idleStill = AnimationClip.still(idleRest.frames[0].sprite)
        static let sleepingStill = AnimationClip.still(sleeping.frames[1].sprite)
        static let workingStill = AnimationClip.still(
            SpriteFrame(layers: cat(legs: .forward, rainbow: .a) + [largeStar(18, 2), smallStar(14, 4)]))
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
        /// A startled hop with an open mouth before flying away.
        static let startle = AnimationClip([
            frame(120, cat(head: .meow)),
            frame(100, cat(legs: .tucked, head: .meow, dy: -2)),
            frame(100, cat(legs: .tucked, head: .meow, dy: -3)),
            frame(100, cat(legs: .tucked, dy: -2)),
            frame(80, cat()),
        ])
        /// A slow yawn with the head raised before wandering off.
        static let yawn = AnimationClip([
            frame(200, cat()),
            frame(150, cat(head: .blink, headDY: -1)),
            frame(600, cat(tail: .down, head: .yawn, headDY: -1)),
            frame(200, cat(head: .blink)),
            frame(200, cat()),
        ])
        /// Standing still for a moment, shown mirrored when the cat turns around.
        static let turn = AnimationClip([
            frame(100, cat())
        ])
        /// Flying on its rainbow, looped while the panel moves.
        static let run = AnimationClip([
            frame(80, cat(legs: .forward, rainbow: .a, dy: -1)),
            frame(80, cat(legs: .back, tail: .down, rainbow: .b, dy: -2)),
            frame(80, cat(legs: .forward, rainbow: .a, dy: -1)),
            frame(80, cat(legs: .back, tail: .down, rainbow: .b)),
        ])
        /// A slow walk with the tail swinging, looped while the panel moves.
        static let walk = AnimationClip([
            frame(180, cat(legs: .forward)),
            frame(180, cat(tail: .down)),
            frame(180, cat(legs: .back)),
            frame(180, cat(tail: .down)),
        ])
        /// Catching breath after coming back.
        static let arrive = AnimationClip([
            frame(150, cat(head: .meow)),
            frame(150, cat(head: .blink)),
            frame(200, cat()),
        ])
    }

    // MARK: Petting

    /// The reaction to a click: the cat purrs with its eyes closed and its cheeks blushing, wags its tail, a heart rises
    /// and it gives a small happy hop.
    private static let petted = AnimationClip([
        frame(120, cat(tail: .down, head: .content)),
        frame(160, cat(head: .content) + [smallHeart(3)]),
        frame(160, cat(tail: .down, head: .content) + [smallHeart(2)]),
        frame(160, cat(head: .content) + [largeHeart(1)]),
        frame(160, cat(tail: .down, head: .content) + [largeHeart(0)]),
        frame(120, cat(legs: .tucked, head: .content, dy: -1) + [largeHeart(0)]),
        frame(200, cat(head: .content) + [largeHeart(0)]),
        frame(200, cat()),
    ])

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
