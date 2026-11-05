// All pixel data of the UFO lives in this file: the palette, the grids, how they are composed into frames, and the
// frame timing of every animation clip. A grey flying saucer with a little green alien in its glass dome; it stands on
// landing legs and, while agents work, hovers up and beams a sheep up from the ground. The state's signs ("!", the ✔
// bubble, "?", "zzz", hearts) are the sheep's (`SheepSprites.Effect`), so every buddy shows the same ones.

enum UFOSprites {
    static let buddy = Buddy(id: .ufo, clips: ClipSet(clip), escape: ClipSet(escapeClip), petted: petted)

    /// Top-left corner of the UFO on the canvas when standing: 18 × 14 pixels, its feet on the bottom row.
    static let ufoX = 2
    static let ufoY = 6

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": SheepSprites.outline,  // outline, eyes, landing legs
        "M": PixelColor(red: 0xC9, green: 0xCD, blue: 0xD8),  // hull, speed lines
        "m": PixelColor(red: 0x8A, green: 0x90, blue: 0xA2),  // hull underside
        "C": PixelColor(red: 0x9F, green: 0xE3, blue: 0xF0),  // glass
        "W": PixelColor(red: 0xFF, green: 0xFF, blue: 0xFF),  // glints
        "A": PixelColor(red: 0x7E, green: 0xD9, blue: 0x57),  // alien
        "a": PixelColor(red: 0x4F, green: 0xA8, blue: 0x3A),  // antennae, closed eyes
        "P": SheepSprites.palette["P"]!,  // open mouth, cheeks
        "Y": PixelColor(red: 0xFF, green: 0xE1, blue: 0x4D),  // light on
        "y": PixelColor(red: 0x8F, green: 0x7B, blue: 0x2E),  // light off
        "R": SheepSprites.palette["R"]!,  // alarm light, the color of "!"
        "H": SheepSprites.palette["H"]!,  // loving light, the color of the hearts
        "B": PixelColor(red: 0xF4, green: 0xFF, blue: 0xB0),  // beam
        "b": PixelColor(red: 0xC8, green: 0xF0, blue: 0x6A),  // beam edge
        "S": SheepSprites.palette["W"]!,  // the beamed sheep: wool,
        "s": SheepSprites.palette["w"]!,  // wool shade,
        "F": SheepSprites.palette["F"]!,  // face
    ]

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The UFO is drawn back to front: beam, beamed sheep, legs, dome, hull. Every part has its place in the UFO
        // (`ufo(face:lights:legs:dy:)`); variants of a part differ only in the alien's face or in the lights.

        /// The glass dome with the alien looking left; `eyes` and `mouth` are its two lowest rows.
        private static func dome(eyes: String = "OOAOOAA", mouth: String = "AAAAAAA") -> [String] {
            [
                "...OOOOOO...",
                ".OOCACCAWOO.",
                "OCCCaCCaCWCO",
                "OCCCAAAAACCO",
                "OCC" + eyes + "CO",
                "OCC" + mouth + "CO",
            ]
        }

        private static let closedEyes = "aaAaaAA"

        static let domeNormal = dome()
        static let domeBlink = dome(eyes: closedEyes)
        /// Eyes turned forward.
        static let domeLook = dome(eyes: "AOOAOOA")
        /// Eyes turned back, to the right.
        static let domeLookBack = dome(eyes: "AAOOAOO")
        /// Mouth open, shouting.
        static let domeShout = dome(mouth: "APPAAAA")
        /// Eyes closed and the cheeks blushing, enjoying being petted.
        static let domeContent = dome(eyes: closedEyes, mouth: "PAAAPAA")
        /// Eyes closed and the mouth wide open, yawning.
        static let domeYawn = dome(eyes: closedEyes, mouth: "APPPAAA")

        /// The hull with four lights, `lights` from left to right.
        private static func hull(_ lights: String) -> [String] {
            let light = Array(lights)
            return [
                "..OOOOOOOOOOOOOO..",
                ".OMMMMMMMMMMMMMWO.",
                "OMM\(light[0])MMM\(light[1])MM\(light[2])MMM\(light[3])MMO",
                ".OmmmmmmmmmmmmmmO.",
                "...OOOOOOOOOOOO...",
            ]
        }

        static let hullEven = hull("YyYy")
        static let hullOdd = hull("yYyY")
        static let hullOuter = hull("YyyY")
        static let hullInner = hull("yYYy")
        static let hullOn = hull("YYYY")
        static let hullOff = hull("yyyy")
        static let hullAlarm = hull("RRRR")
        static let hullLoveEven = hull("HyHy")
        static let hullLoveOdd = hull("yHyH")

        static let legsDown = [
            "....O........O....",
            "...O..........O...",
            "..OOO........OOO..",
        ]
        /// Legs drawn in, for hops.
        static let legsTucked = [
            "...OO........OO..."
        ]

        /// The beam from the underside of the hovering UFO to the ground, its stripes moving up; no outline.
        static let beamA = [
            ".....bBBBBBBb.....",
            ".....b......b.....",
            "....bBBBBBBBBb....",
            "....b........b....",
            "...bBBBBBBBBBBb...",
            "...b..........b...",
            "..bBBBBBBBBBBBBb..",
            "..b............b..",
            ".bBBBBBBBBBBBBBBb.",
        ]
        static let beamB = [
            ".....b......b.....",
            ".....bBBBBBBb.....",
            "....b........b....",
            "....bBBBBBBBBb....",
            "...b..........b...",
            "...bBBBBBBBBBBb...",
            "..b............b..",
            "..bBBBBBBBBBBBBb..",
            ".b..............b.",
        ]

        /// A little sheep facing left, carried up by the beam.
        static let sheep = [
            "..OOOOO.",
            ".OSSSSSO",
            "OFOSSSSO",
            "OFOSSssO",
            ".OOOOOO.",
            "..O..O..",
        ]

        /// Lines trailing behind the flying UFO.
        static let speedLines = [
            "MMM.",
            "....",
            ".MMM",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] = [
        ("domeNormal", Grid.domeNormal),
        ("domeBlink", Grid.domeBlink),
        ("domeLook", Grid.domeLook),
        ("domeLookBack", Grid.domeLookBack),
        ("domeShout", Grid.domeShout),
        ("domeContent", Grid.domeContent),
        ("domeYawn", Grid.domeYawn),
        ("hullEven", Grid.hullEven),
        ("hullOdd", Grid.hullOdd),
        ("hullOuter", Grid.hullOuter),
        ("hullInner", Grid.hullInner),
        ("hullOn", Grid.hullOn),
        ("hullOff", Grid.hullOff),
        ("hullAlarm", Grid.hullAlarm),
        ("hullLoveEven", Grid.hullLoveEven),
        ("hullLoveOdd", Grid.hullLoveOdd),
        ("legsDown", Grid.legsDown),
        ("legsTucked", Grid.legsTucked),
        ("beamA", Grid.beamA),
        ("beamB", Grid.beamB),
        ("sheep", Grid.sheep),
        ("speedLines", Grid.speedLines),
    ]

    // MARK: Sprites

    /// The dome with the alien's faces; like the UFO's other parts, each variant is built once.
    enum Face: CaseIterable {
        case normal, blink, look, lookBack, shout, content, yawn

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        private static let sprites = Dictionary(uniqueKeysWithValues: allCases.map { ($0, UFOSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .normal: Grid.domeNormal
            case .blink: Grid.domeBlink
            case .look: Grid.domeLook
            case .lookBack: Grid.domeLookBack
            case .shout: Grid.domeShout
            case .content: Grid.domeContent
            case .yawn: Grid.domeYawn
            }
        }
    }

    /// The hull with its lights: alternating (`even`, `odd`), chasing (`outer`, `inner`), all on or off, red or pink.
    enum Lights: CaseIterable {
        case even, odd, outer, inner, on, off, alarm, loveEven, loveOdd

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        private static let sprites = Dictionary(uniqueKeysWithValues: allCases.map { ($0, UFOSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .even: Grid.hullEven
            case .odd: Grid.hullOdd
            case .outer: Grid.hullOuter
            case .inner: Grid.hullInner
            case .on: Grid.hullOn
            case .off: Grid.hullOff
            case .alarm: Grid.hullAlarm
            case .loveEven: Grid.hullLoveEven
            case .loveOdd: Grid.hullLoveOdd
            }
        }
    }

    enum Legs {
        case down, tucked

        var sprite: PixelSprite {
            switch self {
            case .down: Part.legsDown
            case .tucked: Part.legsTucked
            }
        }
    }

    enum Beam {
        case a, b

        var sprite: PixelSprite {
            switch self {
            case .a: Part.beamA
            case .b: Part.beamB
            }
        }
    }

    private enum Part {
        static let legsDown = sprite(Grid.legsDown)
        static let legsTucked = sprite(Grid.legsTucked)
        static let beamA = sprite(Grid.beamA)
        static let beamB = sprite(Grid.beamB)
        static let speedLines = sprite(Grid.speedLines)
    }

    // MARK: Frames

    /// The UFO's layers, back to front. `legs` is `nil` while flying or lying on its belly. `dy` moves the whole UFO
    /// (negative is up).
    static func ufo(face: Face = .normal, lights: Lights = .even, legs: Legs? = .down, dy: Int = 0) -> [SpriteLayer] {
        [
            legs.map { layer($0.sprite, 0, 11 + dy) },
            layer(face.sprite, 3, dy),
            layer(lights.sprite, 0, 6 + dy),
        ].compactMap { $0 }
    }

    /// A sprite at a position within the UFO (`ufoX`, `ufoY`).
    private static func layer(_ sprite: PixelSprite, _ x: Int, _ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: sprite, x: ufoX + x, y: ufoY + y)
    }

    /// How high the UFO hovers while it beams: its top one pixel below the top of the canvas.
    private static let hoverDY = -5

    /// Hovering high and beaming: the beam reaches from under the hull to the ground, `sheepY` is the top of the beamed
    /// sheep on the canvas (`nil` once it is inside); below the bottom edge it is cut off. `bob` lifts the UFO by a
    /// pixel; the beam stays.
    private static func beaming(beam: Beam, sheepY: Int?, lights: Lights, bob: Bool) -> [SpriteLayer] {
        let sheep = sheepY.map { y in
            SpriteLayer(sprite: sprite(Array(Grid.sheep.prefix(BuddyCanvas.height - y))), x: 7, y: y)
        }
        return [layer(beam.sprite, 0, hoverDY + 10), sheep].compactMap { $0 }
            + ufo(face: .look, lights: lights, legs: nil, dy: hoverDY - (bob ? 1 : 0))
    }

    private static let checkBubble = SpriteLayer(sprite: SheepSprites.Effect.checkBubble, x: 0, y: 0)
    private static let exclamation = SpriteLayer(sprite: SheepSprites.Effect.exclamation, x: 1, y: 0)
    /// Landed on its belly, legs drawn in, lights off, the alien asleep.
    private static let asleep = ufo(face: .blink, lights: .off, legs: nil, dy: 3)
    private static let smallZ = SpriteLayer(sprite: SheepSprites.Effect.smallZ, x: 8, y: 3)
    private static let largeZ = SpriteLayer(sprite: SheepSprites.Effect.largeZ, x: 13, y: 0)

    private static func speedLines(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: Part.speedLines, x: 18, y: y)
    }

    private static func smallHeart(_ y: Int) -> SpriteLayer {
        SpriteLayer(sprite: SheepSprites.Effect.smallHeart, x: 1, y: y)
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
            frame(500, ufo()),
            frame(500, ufo(lights: .odd)),
        ])
        static let idleBlink = AnimationClip([
            frame(150, ufo(face: .blink)),
            frame(250, ufo()),
        ])
        static let idleLook = AnimationClip([
            frame(400, ufo(face: .look, lights: .odd)),
            frame(400, ufo(face: .lookBack)),
            frame(200, ufo(lights: .odd)),
        ])
        static let sleeping = AnimationClip([
            frame(700, asleep + [smallZ]),
            frame(700, asleep + [smallZ, largeZ]),
        ])
        /// Hovering high and beaming a sheep up into the UFO, bobbing, its lights chasing. The sheep rises out of the
        /// bottom edge a pixel at a time, so the next one never pops up.
        static let working = AnimationClip(
            (0..<14).map { index in
                let even = index.isMultiple(of: 2)
                return frame(
                    110,
                    beaming(
                        beam: even ? .a : .b, sheepY: index < 13 ? BuddyCanvas.height - 1 - index : nil,
                        lights: even ? .outer : .inner, bob: index / 2 % 2 == 1))
            })
        static let blocked = AnimationClip([
            frame(150, ufo(face: .shout, lights: .alarm) + [exclamation]),
            frame(120, ufo(face: .shout, lights: .off, legs: .tucked, dy: -2) + [exclamation]),
            frame(120, ufo(lights: .alarm, legs: .tucked, dy: -3)),
            frame(120, ufo(lights: .off, legs: .tucked, dy: -2)),
            frame(150, ufo(lights: .alarm) + [exclamation]),
            frame(340, ufo(lights: .off)),
        ])
        static let doneJump = AnimationClip([
            frame(150, ufo(lights: .on) + [checkBubble]),
            frame(120, ufo(legs: .tucked, dy: -2) + [checkBubble]),
            frame(120, ufo(lights: .odd, legs: .tucked, dy: -3) + [checkBubble]),
            frame(120, ufo(legs: .tucked, dy: -2) + [checkBubble]),
            frame(290, ufo(face: .blink, lights: .on) + [checkBubble]),
        ])
        static let doneHold = AnimationClip([
            frame(600, ufo(face: .blink, lights: .on) + [checkBubble]),
            frame(400, ufo(lights: .on) + [checkBubble]),
        ])
        static let unknown = AnimationClip([
            frame(800, ufo(lights: .off) + [question(1)], opacity: BuddyCanvas.unknownOpacity),
            frame(800, ufo(lights: .off) + [question(0)], opacity: BuddyCanvas.unknownOpacity),
        ])

        // Still poses: one picture per state that still shows the state's sign, a frame of its clip.
        static let idleStill = AnimationClip.still(idleRest.frames[0].sprite)
        static let sleepingStill = AnimationClip.still(sleeping.frames[1].sprite)
        /// The sheep halfway up the beam.
        static let workingStill = AnimationClip.still(working.frames[8].sprite)
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
        /// A startled hop with the alarm on before flying away.
        static let startle = AnimationClip([
            frame(120, ufo(face: .shout, lights: .alarm)),
            frame(100, ufo(face: .shout, lights: .off, legs: .tucked, dy: -2)),
            frame(100, ufo(face: .shout, lights: .alarm, legs: .tucked, dy: -3)),
            frame(100, ufo(lights: .off, legs: .tucked, dy: -2)),
            frame(80, ufo(lights: .alarm)),
        ])
        /// A slow yawn of the alien before drifting off.
        static let yawn = AnimationClip([
            frame(200, ufo()),
            frame(150, ufo(face: .blink)),
            frame(600, ufo(face: .yawn, lights: .off)),
            frame(200, ufo(face: .blink)),
            frame(200, ufo()),
        ])
        /// Standing still for a moment, shown mirrored when the UFO turns around.
        static let turn = AnimationClip([
            frame(100, ufo())
        ])
        /// Flying fast with the legs drawn in and lines trailing behind, looped while the panel moves.
        static let run = AnimationClip([
            frame(80, ufo(lights: .outer, legs: nil, dy: -1) + [speedLines(9)]),
            frame(80, ufo(lights: .inner, legs: nil, dy: -2) + [speedLines(8)]),
            frame(80, ufo(lights: .outer, legs: nil, dy: -1) + [speedLines(10)]),
            frame(80, ufo(lights: .inner, legs: nil, dy: -2) + [speedLines(9)]),
        ])
        /// Drifting slowly just above the ground, looped while the panel moves.
        static let walk = AnimationClip([
            frame(180, ufo(legs: .tucked, dy: -1)),
            frame(180, ufo(lights: .odd, legs: .tucked, dy: -2)),
            frame(180, ufo(legs: .tucked, dy: -2)),
            frame(180, ufo(lights: .odd, legs: .tucked, dy: -1)),
        ])
        /// Landing after coming back.
        static let arrive = AnimationClip([
            frame(150, ufo(face: .shout, lights: .on, legs: .tucked, dy: -1)),
            frame(150, ufo(face: .blink, lights: .on)),
            frame(200, ufo()),
        ])
    }

    // MARK: Petting

    /// The reaction to a click: the alien closes its eyes and blushes, the lights turn pink and blink, a heart rises and
    /// the UFO gives a small happy hop.
    private static let petted = AnimationClip([
        frame(120, ufo(face: .content, lights: .loveEven)),
        frame(160, ufo(face: .content, lights: .loveOdd) + [smallHeart(3)]),
        frame(160, ufo(face: .content, lights: .loveEven) + [smallHeart(2)]),
        frame(160, ufo(face: .content, lights: .loveOdd) + [largeHeart(1)]),
        frame(160, ufo(face: .content, lights: .loveEven) + [largeHeart(0)]),
        frame(120, ufo(face: .content, lights: .loveOdd, legs: .tucked, dy: -1) + [largeHeart(0)]),
        frame(200, ufo(face: .content, lights: .loveEven) + [largeHeart(0)]),
        frame(200, ufo()),
    ])

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
