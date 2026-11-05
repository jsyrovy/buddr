/// A character that sits on the screen and shows the state of the agents: its name and every clip it plays. Its
/// pixels live in a file of its own (`SheepSprites`); the canvas (`BuddyCanvas`) and the name plate
/// (`NamePlateSprite`) are the same for every buddy.
///
/// What every buddy has to do, checked by the tests for every `BuddyID`:
/// - Face left: running to the right plays the mirrored frames.
/// - Stand on the bottom row of the canvas, centered horizontally: the name plate is placed under its feet.
/// - Keep every clip short (at most 1.6 s): a clip plays to its end before a state change shows.
/// - Make every still pose one short frame of the pictures of its state's clip, so it shows the same sign.
/// - Dim only the `unknown` clips, to `BuddyCanvas.unknownOpacity`.
struct Buddy: Sendable {
    let id: BuddyID
    /// Shown in the menu bar.
    let name: String
    let clips: Clips
    let escape: Escape
    /// The reaction to a click, played as an interjection outside the state machine.
    let petted: AnimationClip
    /// The raw character grids and their palette, kept so tests can validate them.
    let grids: [Grid]
    let palette: [Character: PixelColor]

    /// The clips of the state machine (`BuddyAnimator`), one for every `ClipID`.
    struct Clips: Sendable {
        let idleRest: AnimationClip
        let idleBlink: AnimationClip
        let idleLook: AnimationClip
        let sleeping: AnimationClip
        let working: AnimationClip
        let blocked: AnimationClip
        let doneJump: AnimationClip
        let doneHold: AnimationClip
        let unknown: AnimationClip
        let idleStill: AnimationClip
        let sleepingStill: AnimationClip
        let workingStill: AnimationClip
        let blockedStill: AnimationClip
        let doneStill: AnimationClip
        let unknownStill: AnimationClip

        subscript(id: ClipID) -> AnimationClip {
            switch id {
            case .idleRest: idleRest
            case .idleBlink: idleBlink
            case .idleLook: idleLook
            case .sleeping: sleeping
            case .working: working
            case .blocked: blocked
            case .doneJump: doneJump
            case .doneHold: doneHold
            case .unknown: unknown
            case .idleStill: idleStill
            case .sleepingStill: sleepingStill
            case .workingStill: workingStill
            case .blockedStill: blockedStill
            case .doneStill: doneStill
            case .unknownStill: unknownStill
            }
        }
    }

    /// Clips of leaving the screen – escaping from a fullscreen window or wandering off bored when it hides – and of the
    /// return, played by `BuddyEscape`.
    struct Escape: Sendable {
        /// A startled hop before running away.
        let startle: AnimationClip
        /// A slow yawn before wandering off.
        let yawn: AnimationClip
        /// Standing still for a moment, shown mirrored when the buddy turns around.
        let turn: AnimationClip
        /// Running, looped while the panel moves.
        let run: AnimationClip
        /// A slow walk, looped while the panel moves.
        let walk: AnimationClip
        /// Catching breath after coming back.
        let arrive: AnimationClip
    }

    struct Grid: Sendable {
        let name: String
        let rows: [String]
    }

    /// The same buddy under another name, with `colors` replaced in the layers showing one of `sprites` (the others,
    /// such as effects, keep their colors) and in the palette.
    func recolored(id: BuddyID, name: String, colors: [PixelColor: PixelColor], in sprites: Set<PixelSprite>) -> Buddy {
        let recolor = { (clip: AnimationClip) in Self.recolored(clip, colors: colors, in: sprites) }
        return Buddy(
            id: id, name: name,
            clips: Clips(
                idleRest: recolor(clips.idleRest), idleBlink: recolor(clips.idleBlink),
                idleLook: recolor(clips.idleLook), sleeping: recolor(clips.sleeping), working: recolor(clips.working),
                blocked: recolor(clips.blocked), doneJump: recolor(clips.doneJump), doneHold: recolor(clips.doneHold),
                unknown: recolor(clips.unknown), idleStill: recolor(clips.idleStill),
                sleepingStill: recolor(clips.sleepingStill), workingStill: recolor(clips.workingStill),
                blockedStill: recolor(clips.blockedStill), doneStill: recolor(clips.doneStill),
                unknownStill: recolor(clips.unknownStill)),
            escape: Escape(
                startle: recolor(escape.startle), yawn: recolor(escape.yawn), turn: recolor(escape.turn),
                run: recolor(escape.run), walk: recolor(escape.walk), arrive: recolor(escape.arrive)),
            petted: recolor(petted), grids: grids, palette: palette.mapValues { colors[$0] ?? $0 })
    }

    private static func recolored(
        _ clip: AnimationClip, colors: [PixelColor: PixelColor], in sprites: Set<PixelSprite>
    ) -> AnimationClip {
        AnimationClip(
            clip.frames.map { frame in
                let layers = frame.sprite.layers.map { layer in
                    sprites.contains(layer.sprite)
                        ? SpriteLayer(sprite: layer.sprite.recolored(colors), x: layer.x, y: layer.y) : layer
                }
                return AnimationFrame(
                    sprite: SpriteFrame(layers: layers, opacity: frame.sprite.opacity), duration: frame.duration)
            })
    }

    /// Every clip with a name: the state machine's, the escape's and the petting reaction.
    var allClips: [(name: String, clip: AnimationClip)] {
        ClipID.allCases.map { ("\($0)", clips[$0]) } + [
            ("escapeStartle", escape.startle),
            ("escapeYawn", escape.yawn),
            ("escapeTurn", escape.turn),
            ("escapeRun", escape.run),
            ("escapeWalk", escape.walk),
            ("escapeArrive", escape.arrive),
            ("petted", petted),
        ]
    }
}

/// Every buddy there is, in the order of the menu.
enum BuddyID: String, CaseIterable, Sendable {
    case sheep
    case blackSheep

    var buddy: Buddy {
        switch self {
        case .sheep: SheepSprites.buddy
        case .blackSheep: BlackSheepSprites.buddy
        }
    }
}
