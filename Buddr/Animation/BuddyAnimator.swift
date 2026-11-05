/// The buddy's animation state machine.
///
/// The target state can change at any time, but the clip that is playing always finishes its cycle first; only then
/// is the next clip chosen for the current target state. This avoids jarring cuts in the middle of a jump.
/// The animator is a pure value: `advance()` moves to the next frame and the caller decides when to call it.
///
/// Depending on the `AnimationMode`, a still pose of the state is chosen instead of its clip: always (`off`), or once
/// the buddy has been animated for `animatesFor` since the status changed or `replay()` was called (`onChange`).
struct BuddyAnimator {
    /// After this long in `idle` the buddy falls asleep.
    static let defaultSleepAfter: Duration = .seconds(60)
    /// While `done` persists, every n-th cycle is a jump; the others are a calm hold.
    static let doneJumpEvery = 4

    private(set) var buddy: Buddy
    private(set) var status: AgentStatus
    private(set) var clipID: ClipID
    private(set) var frameIndex = 0
    private(set) var mode: AnimationMode
    /// How long the buddy is animated after a change in the `onChange` mode.
    private var animatesFor: Duration

    private let sleepAfter: Duration
    private var random: SplitMix64
    /// Time spent with `status == .idle` since the status last changed.
    private var idleTime: Duration = .zero
    /// Clips started since the status last changed or `replay()`.
    private var cyclesInStatus = 0
    /// Time played since the status last changed or `replay()`.
    private var timeSinceChange: Duration = .zero

    init(
        buddy: Buddy = BuddyID.sheep.buddy, status: AgentStatus = .unknown, mode: AnimationMode = .always,
        animatesFor: Duration = .zero, sleepAfter: Duration = defaultSleepAfter,
        seed: UInt64 = .random(in: .min ... .max)
    ) {
        self.buddy = buddy
        self.status = status
        self.mode = mode
        self.animatesFor = animatesFor
        self.sleepAfter = sleepAfter
        self.random = SplitMix64(seed: seed)
        self.clipID = .unknown
        self.clipID = chooseClip()
    }

    var clip: AnimationClip {
        buddy.clips[clipID]
    }

    var frame: AnimationFrame {
        clip.frames[frameIndex]
    }

    /// Shows `buddy` right away, playing the current clip again from its start. Meant for a moment when the buddy is not
    /// on the screen (`BuddyEscape` swaps it while away): unlike a state change it cuts the running clip.
    mutating func setBuddy(_ buddy: Buddy) {
        self.buddy = buddy
        frameIndex = 0
    }

    /// Sets the target state; it takes effect when the current clip ends.
    mutating func setStatus(_ newStatus: AgentStatus) {
        guard newStatus != status else { return }
        status = newStatus
        idleTime = .zero
        cyclesInStatus = 0
        timeSinceChange = .zero
    }

    /// Plays the current status from its start again, as after a status change; it takes effect when the current clip
    /// ends. Called when another agent starts waiting for the user while the aggregated status stays the same.
    mutating func replay() {
        cyclesInStatus = 0
        timeSinceChange = .zero
    }

    /// Takes effect when the current clip ends. Time already played since the last change counts towards the new
    /// `animatesFor`.
    mutating func setAnimation(_ mode: AnimationMode, for animatesFor: Duration) {
        self.mode = mode
        self.animatesFor = animatesFor
    }

    /// Moves past the current frame, which is assumed to have been shown for its full duration.
    mutating func advance() {
        if status == .idle {
            idleTime += frame.duration
        }
        timeSinceChange += frame.duration
        if frameIndex + 1 < clip.frames.count {
            frameIndex += 1
        } else {
            clipID = chooseClip()
            frameIndex = 0
        }
    }

    private var isAnimated: Bool {
        switch mode {
        case .off: false
        case .onChange: timeSinceChange < animatesFor
        case .always: true
        }
    }

    private mutating func chooseClip() -> ClipID {
        defer { cyclesInStatus += 1 }
        guard isAnimated else {
            return stillPose()
        }
        switch status {
        case .working:
            return .working
        case .blocked:
            return .blocked
        case .done:
            return cyclesInStatus % Self.doneJumpEvery == 0 ? .doneJump : .doneHold
        case .unknown:
            return .unknown
        case .idle:
            if idleTime >= sleepAfter {
                return .sleeping
            }
            switch Int.random(in: 0..<10, using: &random) {
            case 0..<7: return .idleRest
            case 7..<9: return .idleBlink
            default: return .idleLook
            }
        }
    }

    private func stillPose() -> ClipID {
        switch status {
        case .working: .workingStill
        case .blocked: .blockedStill
        case .done: .doneStill
        case .unknown: .unknownStill
        case .idle: idleTime >= sleepAfter ? .sleepingStill : .idleStill
        }
    }
}
