import Observation

/// Plays the sheep animation in real time and publishes the current picture to SwiftUI.
///
/// Normally the frames come from the `SheepAnimator` state machine. A scripted clip (`play`, `loop`) takes over until
/// `endScript()`; the state machine keeps its target status meanwhile and continues where it stopped.
@MainActor
@Observable
final class SheepAnimationDriver {
    private(set) var sprite: SpriteFrame

    @ObservationIgnored private var animator: SheepAnimator
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var script: Script?
    @ObservationIgnored private var cycleEndWaiters: [CheckedContinuation<Void, Never>] = []

    private struct Script {
        let clip: AnimationClip
        let loops: Bool
        var frameIndex = 0
        /// Resumed when a non-looping clip has played its last frame; the last frame stays on screen until the next
        /// script or `endScript()`.
        var completion: CheckedContinuation<Void, Never>?
    }

    /// `sleep` is replaced in tests to play the animation frame by frame.
    init(
        animator: SheepAnimator = SheepAnimator(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.animator = animator
        self.sleep = sleep
        self.sprite = animator.frame.sprite
    }

    func setStatus(_ status: AgentStatus) {
        animator.setStatus(status)
    }

    func start() {
        guard task == nil else { return }
        startLoop()
    }

    /// Stops the animation and waits for its loop to end. Pending `play` and `waitForCycleEnd` calls return.
    func stop() async {
        guard let task else { return }
        self.task = nil
        task.cancel()
        finishScript()
        resumeCycleEndWaiters()
        await task.value
    }

    /// Returns when the state machine's current clip has played to its end. Returns right away while a script plays
    /// or the animation is stopped.
    func waitForCycleEnd() async {
        guard task != nil, script == nil else { return }
        await withCheckedContinuation { cycleEndWaiters.append($0) }
    }

    /// Shows `clip` once, starting right away, and returns after its last frame has been shown for its duration.
    func play(_ clip: AnimationClip, mirrored: Bool = false) async {
        guard task != nil else { return }
        await withCheckedContinuation { continuation in
            setScript(Script(clip: Self.oriented(clip, mirrored), loops: false, completion: continuation))
        }
    }

    /// Repeats `clip`, starting right away, until another script or `endScript()`.
    func loop(_ clip: AnimationClip, mirrored: Bool = false) {
        setScript(Script(clip: Self.oriented(clip, mirrored), loops: true))
    }

    /// Hands the animation back to the state machine.
    func endScript() {
        setScript(nil)
    }

    private static func oriented(_ clip: AnimationClip, _ mirrored: Bool) -> AnimationClip {
        mirrored ? clip.mirrored(canvasWidth: SheepSprites.canvasWidth) : clip
    }

    private var currentFrame: AnimationFrame {
        if let script {
            return script.clip.frames[script.frameIndex]
        }
        return animator.frame
    }

    private func setScript(_ newScript: Script?) {
        finishScript()
        script = newScript
        publish()
        // Restart the timer so the new frame gets its full duration instead of the rest of the previous one.
        if task != nil {
            startLoop()
        }
    }

    /// Starts the frame loop; a running loop is cancelled and ends before the new one sleeps for the first time.
    private func startLoop() {
        let previous = task
        previous?.cancel()
        task = Task { [weak self, sleep] in
            await previous?.value
            while !Task.isCancelled {
                guard let duration = self?.currentFrame.duration else { return }
                try? await sleep(duration)
                // A cancelled sleep must not show one more frame.
                guard !Task.isCancelled else { return }
                self?.advance()
            }
        }
    }

    private func advance() {
        if var script {
            if script.frameIndex + 1 < script.clip.frames.count {
                script.frameIndex += 1
            } else if script.loops {
                script.frameIndex = 0
            } else {
                // The last frame stays on screen.
                finishScript()
                return
            }
            self.script = script
        } else {
            animator.advance()
            if animator.frameIndex == 0 {
                resumeCycleEndWaiters()
            }
        }
        publish()
    }

    /// Lets a pending `play` return.
    private func finishScript() {
        let completion = script?.completion
        script?.completion = nil
        completion?.resume()
    }

    private func resumeCycleEndWaiters() {
        let waiters = cycleEndWaiters
        cycleEndWaiters = []
        waiters.forEach { $0.resume() }
    }

    private func publish() {
        // @Observable skips the notification when the new frame equals the current one.
        sprite = currentFrame.sprite
    }
}
