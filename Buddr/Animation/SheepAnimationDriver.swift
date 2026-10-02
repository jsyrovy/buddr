import Observation

/// Plays the sheep animation in real time and publishes the current picture to SwiftUI.
@MainActor
@Observable
final class SheepAnimationDriver {
    private(set) var sprite: SpriteFrame

    @ObservationIgnored private var animator: SheepAnimator
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var task: Task<Void, Never>?

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
        task = Task { [weak self, sleep] in
            while !Task.isCancelled {
                guard let duration = self?.animator.frame.duration else { return }
                try? await sleep(duration)
                // A cancelled sleep must not show one more frame.
                guard !Task.isCancelled else { return }
                self?.advance()
            }
        }
    }

    /// Stops the animation and waits for its loop to end.
    func stop() async {
        guard let task else { return }
        self.task = nil
        task.cancel()
        await task.value
    }

    private func advance() {
        animator.advance()
        // @Observable skips the notification when the new frame equals the current one.
        sprite = animator.frame.sprite
    }
}
