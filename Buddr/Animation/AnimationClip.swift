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

    /// The clip with every layer that shows one of the keys of `sprites` showing its value instead.
    func replacingSprites(_ sprites: [PixelSprite: PixelSprite]) -> AnimationClip {
        AnimationClip(
            frames.map { AnimationFrame(sprite: $0.sprite.replacingSprites(sprites), duration: $0.duration) })
    }

    /// The clip with every frame flipped horizontally within a canvas `canvasWidth` pixels wide.
    func mirrored(canvasWidth: Int) -> AnimationClip {
        AnimationClip(
            frames.map { AnimationFrame(sprite: $0.sprite.mirrored(canvasWidth: canvasWidth), duration: $0.duration) })
    }
}

/// Every clip of the state machine. Each buddy has its own pixels and timing of every clip (`Buddy.Clips`).
enum ClipID: CaseIterable, Hashable, Sendable {
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
    /// Still poses, shown instead of the clips above while the buddy is not animated (`AnimationMode`).
    case idleStill
    case sleepingStill
    case workingStill
    case blockedStill
    case doneStill
    case unknownStill
}

/// Every clip of leaving the screen – escaping from a fullscreen window or wandering off bored – and of coming back.
enum EscapeClipID: CaseIterable, Hashable, Sendable {
    /// A startled hop before running away.
    case startle
    /// A slow yawn before wandering off.
    case yawn
    /// Standing still for a moment, shown mirrored when the buddy turns around.
    case turn
    /// Running, looped while the panel moves.
    case run
    /// A slow walk, looped while the panel moves.
    case walk
    /// Catching breath after coming back.
    case arrive
}
