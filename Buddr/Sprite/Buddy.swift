/// A character that sits on the screen and shows the state of the agents: every clip it plays. Its
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
    /// The clips of the state machine (`BuddyAnimator`).
    let clips: ClipSet<ClipID>
    /// The clips of leaving the screen and coming back, played by `BuddyEscape`.
    let escape: ClipSet<EscapeClipID>
    /// The reaction to a click, played as an interjection outside the state machine.
    let petted: AnimationClip

    /// Every clip with a name: the state machine's, the escape's and the petting reaction.
    var allClips: [(name: String, clip: AnimationClip)] {
        ClipID.allCases.map { ("\($0)", clips[$0]) } + EscapeClipID.allCases.map { ("escape.\($0)", escape[$0]) }
            + [("petted", petted)]
    }
}

/// One clip for every key of `ID`: a buddy's clips of the state machine (`ClipID`) or of the escape (`EscapeClipID`).
struct ClipSet<ID: CaseIterable & Hashable & Sendable>: Sendable {
    private let clips: [ID: AnimationClip]

    /// `clip` gives the clip of every key; an exhaustive `switch` there makes sure none is missing.
    init(_ clip: (ID) -> AnimationClip) {
        clips = Dictionary(uniqueKeysWithValues: ID.allCases.map { ($0, clip($0)) })
    }

    subscript(id: ID) -> AnimationClip {
        clips[id]!
    }
}

/// Every buddy there is, in the order of the menu.
enum BuddyID: String, CaseIterable, Sendable {
    case sheep
    case rainbowCat
    case ufo

    /// Shown in the menu bar. Known without building the buddy.
    var name: String {
        switch self {
        case .sheep: "Sheep"
        case .rainbowCat: "Rainbow Cat"
        case .ufo: "UFO"
        }
    }

    var buddy: Buddy {
        switch self {
        case .sheep: SheepSprites.buddy
        case .rainbowCat: RainbowCatSprites.buddy
        case .ufo: UFOSprites.buddy
        }
    }
}
