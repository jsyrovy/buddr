import Observation

/// Plays the sheep animation in real time and publishes the current picture to SwiftUI.
@MainActor
@Observable
final class SheepAnimationDriver {
    private(set) var sprite: SpriteFrame

    @ObservationIgnored private var animator: SheepAnimator
    @ObservationIgnored private var task: Task<Void, Never>?

    init(animator: SheepAnimator = SheepAnimator()) {
        self.animator = animator
        self.sprite = animator.frame.sprite
    }

    func setStatus(_ status: AgentStatus) {
        animator.setStatus(status)
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let duration = self?.animator.frame.duration else { return }
                try? await Task.sleep(for: duration)
                self?.advance()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func advance() {
        animator.advance()
        let next = animator.frame.sprite
        // Assigning an equal value would still invalidate the view.
        if next != sprite {
            sprite = next
        }
    }
}
