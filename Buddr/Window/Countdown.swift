/// A restartable one-shot timer on the main actor. Starting it again replaces the running countdown: a cancelled one
/// ends before the new one sleeps, so two never sleep at once and a stale one never fires.
@MainActor
final class Countdown {
    private let sleep: @Sendable (Duration) async throws -> Void
    /// The latest countdown; once cancelled, it may still be ending.
    private var task: Task<Void, Never>?

    /// `sleep` is replaced in tests to end the countdown on demand.
    init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    /// Runs `action` after `delay`, unless the countdown is started again or cancelled meanwhile.
    func start(after delay: Duration, then action: @escaping @MainActor () -> Void) {
        let previous = task
        previous?.cancel()
        task = Task { [sleep] in
            await previous?.value
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
    }
}
