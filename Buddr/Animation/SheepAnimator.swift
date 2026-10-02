/// The sheep's animation state machine.
///
/// The target state can change at any time, but the clip that is playing always finishes its cycle first; only then
/// is the next clip chosen for the current target state. This avoids jarring cuts in the middle of a jump.
/// The animator is a pure value: `advance()` moves to the next frame and the caller decides when to call it.
struct SheepAnimator {
    /// After this long in `idle` the sheep falls asleep.
    static let defaultSleepAfter: Duration = .seconds(60)
    /// While `done` persists, every n-th cycle is a jump; the others are a calm hold.
    static let doneJumpEvery = 4

    private(set) var status: AgentStatus
    private(set) var clipID: SheepClipID
    private(set) var frameIndex = 0

    private let clips: [SheepClipID: AnimationClip]
    private let sleepAfter: Duration
    private var random: SplitMix64
    /// Time spent with `status == .idle` since the status last changed.
    private var idleTime: Duration = .zero
    /// Clips started since the status last changed.
    private var cyclesInStatus = 0

    init(
        status: AgentStatus = .unknown, clips: [SheepClipID: AnimationClip] = SheepSprites.clips,
        sleepAfter: Duration = defaultSleepAfter, seed: UInt64 = .random(in: .min ... .max)
    ) {
        precondition(SheepClipID.allCases.allSatisfy { clips[$0] != nil }, "Every clip needs frames")
        self.status = status
        self.clips = clips
        self.sleepAfter = sleepAfter
        self.random = SplitMix64(seed: seed)
        self.clipID = .unknown
        self.clipID = chooseClip()
    }

    var clip: AnimationClip {
        clips[clipID]!
    }

    var frame: AnimationFrame {
        clip.frames[frameIndex]
    }

    /// Sets the target state; it takes effect when the current clip ends.
    mutating func setStatus(_ newStatus: AgentStatus) {
        guard newStatus != status else { return }
        status = newStatus
        idleTime = .zero
        cyclesInStatus = 0
    }

    /// Moves past the current frame, which is assumed to have been shown for its full duration.
    mutating func advance() {
        if status == .idle {
            idleTime += frame.duration
        }
        if frameIndex + 1 < clip.frames.count {
            frameIndex += 1
        } else {
            clipID = chooseClip()
            frameIndex = 0
        }
    }

    private mutating func chooseClip() -> SheepClipID {
        defer { cyclesInStatus += 1 }
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
}
