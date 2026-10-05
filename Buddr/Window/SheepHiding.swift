import Observation
import os

/// Decides when the sheep hides: after `delay` of calm (see `HideMode`), and back at once when it isn't calm anymore.
///
/// The countdown starts again whenever the status or the settings change, when the sheep is petted
/// (`restartCountdown()`) and when it is called back (`show()`). While hidden, a change between two calm statuses
/// keeps it hidden. Moving the panel is up to `onChange`.
@MainActor
@Observable
final class SheepHiding {
    private static let logger = Logger(subsystem: "cz.jsyrovy.buddr", category: "hiding")

    private(set) var isHidden = false

    /// Called when `isHidden` changed.
    @ObservationIgnored var onChange: (@MainActor (Bool) -> Void)?

    @ObservationIgnored private var mode = HideMode.never
    @ObservationIgnored private var delay = Duration.zero
    @ObservationIgnored private var status = AgentStatus.unknown
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    /// The latest countdown; once cancelled, it may still be ending.
    @ObservationIgnored private var countdown: Task<Void, Never>?

    /// `sleep` is replaced in tests to end the countdown on demand.
    init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    func setMode(_ mode: HideMode, after delay: Duration) {
        guard mode != self.mode || delay != self.delay else { return }
        self.mode = mode
        self.delay = delay
        update()
    }

    func setStatus(_ status: AgentStatus) {
        guard status != self.status else { return }
        self.status = status
        update()
    }

    /// Starts the countdown again, e.g. when the sheep was petted. Does nothing while it is hidden.
    func restartCountdown() {
        guard !isHidden else { return }
        update()
    }

    /// Calls the sheep back; it hides again after another `delay` of calm.
    func show() {
        guard isHidden else { return }
        setHidden(false)
        update()
    }

    private func update() {
        guard mode.isCalm(status) else {
            countdown?.cancel()
            setHidden(false)
            return
        }
        if !isHidden {
            startCountdown()
        }
    }

    /// Starts the countdown; a running one is cancelled and ends before the new one sleeps.
    private func startCountdown() {
        let previous = countdown
        previous?.cancel()
        countdown = Task { [weak self, sleep, delay] in
            await previous?.value
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.setHidden(true)
        }
    }

    private func setHidden(_ hidden: Bool) {
        guard hidden != isHidden else { return }
        isHidden = hidden
        Self.logger.info("\(hidden ? "Hiding" : "Showing", privacy: .public) the sheep")
        onChange?(hidden)
    }
}
