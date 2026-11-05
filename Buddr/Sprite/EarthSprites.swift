import Foundation

// All pixel data of the Earth lives in this file: the palette, the grids, how they are composed into frames, and the
// frame timing of every animation clip. A little planet with a face; its continents turn with it, and while agents
// work it spins and the Moon circles it. The state's signs ("!", the ✔ bubble, "?", "zzz", hearts) are the sheep's
// (`SheepSprites.Effect`), so every buddy shows the same ones.

enum EarthSprites {
    static let buddy = Buddy(id: .earth, clips: ClipSet(clip), escape: ClipSet(escapeClip), petted: petted)

    /// Top-left corner of the globe on the canvas when resting: 16 × 16 pixels, its bottom on the bottom row.
    static let earthX = 3
    static let earthY = 4

    // MARK: Palette

    static let palette: [Character: PixelColor] = [
        "O": SheepSprites.outline,  // outline, eyes, mouth
        "B": PixelColor(red: 0x3B, green: 0x82, blue: 0xDB),  // ocean
        "b": PixelColor(red: 0x2A, green: 0x5C, blue: 0xA8),  // ocean in shade
        "L": PixelColor(red: 0x62, green: 0xBE, blue: 0x4E),  // land
        "l": PixelColor(red: 0x3F, green: 0x8A, blue: 0x3B),  // land in shade
        "I": PixelColor(red: 0xF4, green: 0xF8, blue: 0xFC),  // ice
        "i": PixelColor(red: 0xBE, green: 0xCE, blue: 0xDE),  // ice in shade
        "N": PixelColor(red: 0x29, green: 0x44, blue: 0x86),  // ocean at night
        "n": PixelColor(red: 0x3A, green: 0x5E, blue: 0x4C),  // land at night
        "Y": PixelColor(red: 0xFF, green: 0xE1, blue: 0x4D),  // city lights
        "P": SheepSprites.palette["P"]!,  // cheeks, open mouth
        "M": PixelColor(red: 0xD4, green: 0xD6, blue: 0xDC),  // moon
        "m": PixelColor(red: 0x9A, green: 0x9E, blue: 0xAA),  // moon craters and shade
    ]

    // MARK: Grids

    /// Raw character grids, kept separate from the built sprites so tests can validate them.
    enum Grid {
        // The Earth is drawn back to front: the Moon behind it, the globe, the face, the Moon in front of it. The globe
        // is made from the map (`globe(turn:night:)`), seen as a sphere: the middle of each row shows more of the map
        // than its edges, and the lower right edge is in shade.

        /// The globe's outline; its inner rows are the 14 rows of the map.
        static let disc = [
            "......OOOO......",
            "....OO....OO....",
            "...O........O...",
            "..O..........O..",
            ".O............O.",
            ".O............O.",
            "O..............O",
            "O..............O",
            "O..............O",
            "O..............O",
            ".O............O.",
            ".O............O.",
            "..O..........O..",
            "...O........O...",
            "....OO....OO....",
            "......OOOO......",
        ]

        /// The whole world from 180° W eastwards, 11.25° a column, from the North Pole to the South Pole.
        static let map = [
            "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII",
            "BLLLLLLLLLBIIIIBBLLBLLLLLLLLLLLL",
            "BBLLLLLLLLBBIIBBLLLLLLLLLLLLLLLB",
            "BBBLLLLLLLLBBBBLLLLLLLLLLLLLLLBB",
            "BBBBLLLLLLBBBBBLLBLLLLLLLLLLLLBB",
            "BBBBBLLLLBBBBBLLLLLLBLLLLLLLBBBB",
            "BBBBBBBLLBBBBBLLLLLLBBBLBLLBBBBB",
            "BBBBBBBBBLLLLBBBBLLLLBBBBBLLLBBB",
            "BBBBBBBBBLLLLLBBBLLLLBBBBBBLLLBB",
            "BBBBBBBBBBLLLBBBBBLLBBBBBBLLLLBB",
            "BBBBBBBBBBLLBBBBBBBBBBBBBBBBBBLB",
            "BBBBBBBBBBBLBBBBBBBBBBBBBBBBBBBB",
            "IIBBBBBBBBIIIIBBBBBIIIIIIIIIBBBI",
            "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII",
        ]

        /// The map column in the middle of the globe at rest: the face on the Atlantic, Europe and Africa beside it.
        static let restColumn = 15.0

        /// The globe turned eastwards by `turn` map columns. At night the oceans and land are dark and some land
        /// shows city lights (`lights` picks which).
        static func globe(turn: Int, night: Bool = false, lights: Int = 0) -> [String] {
            disc.enumerated().map { y, row in
                let outline = Array(row)
                let inner = outline.indices.filter { x in outline[x] == "." && isInside(x, y) }
                guard let left = inner.first, let right = inner.last else { return row }
                let half = Double(right - left + 1) / 2
                let center = Double(left) + half
                return String(
                    outline.indices.map { x -> Character in
                        guard inner.contains(x) else { return outline[x] }
                        let u = (Double(x) + 0.5 - center) / half
                        let column = restColumn - Double(turn) + asin(u) * Double(map[0].count) / 2 / .pi
                        let count = map[0].count
                        let index = ((Int(column.rounded(.down)) % count) + count) % count
                        let ground = Array(map[y - 1])[index]
                        if night {
                            return switch ground {
                            case "B": "N"
                            case "L": ((x &* 73) ^ (y &* 151) ^ (lights &* 37)) % 5 == 0 ? "Y" : "n"
                            default: "i"
                            }
                        }
                        return inShade(x, y) ? shade(ground) : ground
                    })
            }
        }

        /// Between the outline's left and right pixel of its row.
        private static func isInside(_ x: Int, _ y: Int) -> Bool {
            let row = Array(disc[y])
            guard let first = row.firstIndex(of: "O"), let last = row.lastIndex(of: "O") else { return false }
            return x > first && x < last && y > 0 && y < disc.count - 1
        }

        /// The lower right edge, turned away from a light at the upper left.
        private static func inShade(_ x: Int, _ y: Int) -> Bool {
            let nx = (Double(x) + 0.5 - 8) / 8
            let ny = (Double(y) + 0.5 - 8) / 8
            let nz = (max(0, 1 - nx * nx - ny * ny)).squareRoot()
            return -0.45 * nx - 0.45 * ny + 0.77 * nz < 0.2
        }

        private static func shade(_ ground: Character) -> Character {
            switch ground {
            case "B": "b"
            case "L": "l"
            default: "i"
            }
        }

        /// The face looking left, drawn over the globe; `eyes` are its two upper rows, `mouth` its two lowest.
        private static func face(
            eyes: [String] = [".O..O.", ".O..O."], cheeks: String = "......", mouth: [String] = [".O..O.", "..OO.."]
        ) -> [String] {
            eyes + [cheeks] + mouth
        }

        private static let closedEyes = ["......", "OO.OO."]

        static let faceNormal = face()
        static let faceBlink = face(eyes: closedEyes)
        /// Eyes turned forward.
        static let faceLook = face(eyes: ["..O..O", "..O..O"])
        /// A wide grin.
        static let faceHappy = face(mouth: ["O....O", ".OOOO."])
        /// Mouth open, shouting.
        static let faceShout = face(mouth: ["..OO..", ".OPPO."])
        /// Eyes closed and the cheeks blushing, enjoying being petted.
        static let faceContent = face(eyes: closedEyes, cheeks: "P....P")
        /// Eyes closed and the mouth wide open, yawning.
        static let faceYawn = face(eyes: closedEyes, mouth: ["..OO..", "..PP.."])

        static let moon = [
            ".OO.",
            "OMmO",
            "OmMO",
            ".OO.",
        ]
    }

    /// Every grid with a name, for validation in tests.
    static let allGrids: [(name: String, rows: [String])] =
        (0..<Grid.map[0].count).map { ("globe\($0)", Grid.globe(turn: $0)) }
        + (0..<2).map { ("globeNight\($0)", Grid.globe(turn: 0, night: true, lights: $0)) } + [
            ("disc", Grid.disc),
            ("map", Grid.map),
            ("faceNormal", Grid.faceNormal),
            ("faceBlink", Grid.faceBlink),
            ("faceLook", Grid.faceLook),
            ("faceHappy", Grid.faceHappy),
            ("faceShout", Grid.faceShout),
            ("faceContent", Grid.faceContent),
            ("faceYawn", Grid.faceYawn),
            ("moon", Grid.moon),
        ]

    // MARK: Sprites

    /// The globe turned by every whole map column, built once.
    private static let globes = (0..<Grid.map[0].count).map { sprite(Grid.globe(turn: $0)) }
    private static let nightGlobes = (0..<2).map { sprite(Grid.globe(turn: 0, night: true, lights: $0)) }

    enum Face: CaseIterable {
        case normal, blink, look, happy, shout, content, yawn

        var sprite: PixelSprite {
            Self.sprites[self]!
        }

        private static let sprites = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, EarthSprites.sprite($0.grid)) })

        private var grid: [String] {
            switch self {
            case .normal: Grid.faceNormal
            case .blink: Grid.faceBlink
            case .look: Grid.faceLook
            case .happy: Grid.faceHappy
            case .shout: Grid.faceShout
            case .content: Grid.faceContent
            case .yawn: Grid.faceYawn
            }
        }
    }

    private enum Part {
        static let moon = sprite(Grid.moon)
    }

    // MARK: Frames

    /// The globe turned by `turn` map columns with a face; `dy` moves it (negative is up). `night` shows the dark side
    /// with its city lights.
    static func earth(face: Face = .normal, turn: Int = 0, night: Int? = nil, dy: Int = 0) -> [SpriteLayer] {
        let count = globes.count
        let globe = night.map { nightGlobes[$0] } ?? globes[((turn % count) + count) % count]
        return [
            SpriteLayer(sprite: globe, x: earthX, y: earthY + dy),
            SpriteLayer(sprite: face.sprite, x: earthX + 3, y: earthY + 7 + dy),
        ]
    }

    /// The Moon `step` of `steps` along its orbit, starting at the left; in front of the Earth on the lower half of
    /// the orbit, behind it on the upper.
    private static func withMoon(_ earth: [SpriteLayer], step: Int, of steps: Int) -> [SpriteLayer] {
        let angle = Double(step) / Double(steps) * 2 * .pi
        let x = 11 - 9 * cos(angle) - 2
        let y = 12 + 6 * sin(angle) - 2
        let moon = SpriteLayer(sprite: Part.moon, x: Int(x.rounded()), y: Int(y.rounded()))
        return sin(angle) > 0.01 ? earth + [moon] : [moon] + earth
    }

    private static let largeDust = SpriteLayer(sprite: SheepSprites.Effect.largeDust, x: 17, y: 16)
    private static let smallDust = SpriteLayer(sprite: SheepSprites.Effect.smallDust, x: 18, y: 17)

    private static let checkBubble = SpriteLayer(sprite: SheepSprites.Effect.checkBubble, x: 0, y: 0)
    private static let exclamation = SpriteLayer(sprite: SheepSprites.Effect.exclamation, x: 1, y: 0)
    private static let smallZ = SpriteLayer(sprite: SheepSprites.Effect.smallZ, x: 10, y: 1)
    private static let largeZ = SpriteLayer(sprite: SheepSprites.Effect.largeZ, x: 15, y: 0)

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
            frame(1_000, earth())
        ])
        static let idleBlink = AnimationClip([
            frame(150, earth(face: .blink)),
            frame(250, earth()),
        ])
        static let idleLook = AnimationClip([
            frame(600, earth(face: .look)),
            frame(200, earth()),
        ])
        /// The night side with its city lights twinkling.
        static let sleeping = AnimationClip([
            frame(700, earth(face: .blink, night: 0) + [smallZ]),
            frame(700, earth(face: .blink, night: 1) + [smallZ, largeZ]),
        ])
        /// Spinning a whole turn while the Moon circles once; it ends where it started.
        static let working = AnimationClip(
            (0..<16).map { index in
                frame(100, withMoon(earth(turn: index * 2), step: index, of: 16))
            })
        /// Shouting and hopping, the "!" blinking.
        static let blocked = AnimationClip([
            frame(150, earth(face: .shout) + [exclamation]),
            frame(120, earth(face: .shout, dy: -2) + [exclamation]),
            frame(120, earth(dy: -3)),
            frame(120, earth(dy: -2)),
            frame(150, earth() + [exclamation]),
            frame(340, earth()),
        ])
        /// A happy jump with a little spin.
        static let doneJump = AnimationClip([
            frame(150, earth(face: .happy) + [checkBubble]),
            frame(120, earth(face: .happy, turn: 1, dy: -2) + [checkBubble]),
            frame(120, earth(face: .happy, turn: 2, dy: -3) + [checkBubble]),
            frame(120, earth(face: .happy, turn: 1, dy: -2) + [checkBubble]),
            frame(290, earth(face: .happy) + [checkBubble]),
        ])
        static let doneHold = AnimationClip([
            frame(600, earth(face: .happy) + [checkBubble]),
            frame(400, earth() + [checkBubble]),
        ])
        static let unknown = AnimationClip([
            frame(800, earth() + [question(1)], opacity: BuddyCanvas.unknownOpacity),
            frame(800, earth() + [question(0)], opacity: BuddyCanvas.unknownOpacity),
        ])

        // Still poses: one picture per state that still shows the state's sign, a frame of its clip.
        static let idleStill = AnimationClip.still(idleRest.frames[0].sprite)
        static let sleepingStill = AnimationClip.still(sleeping.frames[1].sprite)
        static let workingStill = AnimationClip.still(working.frames[4].sprite)
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
        /// A startled hop before rolling away.
        static let startle = AnimationClip([
            frame(120, earth(face: .shout)),
            frame(100, earth(face: .shout, dy: -2)),
            frame(100, earth(face: .shout, dy: -3)),
            frame(100, earth(dy: -2)),
            frame(80, earth(face: .shout)),
        ])
        /// A slow yawn before rolling off.
        static let yawn = AnimationClip([
            frame(200, earth()),
            frame(150, earth(face: .blink)),
            frame(600, earth(face: .yawn)),
            frame(200, earth(face: .blink)),
            frame(200, earth()),
        ])
        /// Standing still for a moment, shown mirrored when the Earth turns around.
        static let turn = AnimationClip([
            frame(100, earth())
        ])
        /// Rolling fast, spinning a whole turn and bouncing, dust behind; looped while the panel moves.
        static let run = AnimationClip(
            (0..<8).map { index in
                let even = index.isMultiple(of: 2)
                return frame(80, earth(turn: index * 4, dy: even ? 0 : -1) + [even ? largeDust : smallDust])
            })
        /// Rolling slowly, a whole turn, looped while the panel moves.
        static let walk = AnimationClip(
            (0..<8).map { index in
                frame(180, earth(turn: index * 4, dy: index / 2 % 2 == 1 ? -1 : 0))
            })
        /// Stopping with a little bounce after coming back.
        static let arrive = AnimationClip([
            frame(150, earth(face: .shout, dy: -1)),
            frame(150, earth(face: .blink)),
            frame(200, earth()),
        ])
    }

    // MARK: Petting

    /// The reaction to a click: the Earth closes its eyes and blushes, a heart rises and it gives a small happy hop.
    private static let petted = AnimationClip([
        frame(120, earth(face: .content)),
        frame(160, earth(face: .content) + [smallHeart(3)]),
        frame(160, earth(face: .content) + [smallHeart(2)]),
        frame(160, earth(face: .content) + [largeHeart(1)]),
        frame(160, earth(face: .content) + [largeHeart(0)]),
        frame(120, earth(face: .content, dy: -1) + [largeHeart(0)]),
        frame(200, earth(face: .content) + [largeHeart(0)]),
        frame(200, earth()),
    ])

    private static func sprite(_ rows: [String]) -> PixelSprite {
        PixelSprite(rows: rows, palette: palette)
    }
}
