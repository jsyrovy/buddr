/// A picture shown for a fixed time.
struct AnimationFrame: Hashable, Sendable {
    let sprite: SpriteFrame
    let duration: Duration
}

/// A sequence of frames that always plays to its end (one cycle) before anything else is shown.
struct AnimationClip: Hashable, Sendable {
    let frames: [AnimationFrame]

    init(_ frames: [AnimationFrame]) {
        precondition(!frames.isEmpty, "A clip needs at least one frame")
        self.frames = frames
    }

    var cycleDuration: Duration {
        frames.reduce(.zero) { $0 + $1.duration }
    }
}

/// Every clip the sheep can play. The pixels and timing of each clip live in `SheepSprites.clips`.
enum SheepClipID: CaseIterable, Hashable, Sendable {
    case idleRest
    case idleBlink
    case idleLook
    case sleeping
    case working
    case blocked
    /// Played when the state becomes `done`, and every few cycles while it stays `done`.
    case doneJump
    case doneHold
    case unknown
}
