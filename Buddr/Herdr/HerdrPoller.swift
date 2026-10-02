import os

/// Polls herdr periodically and reports changed snapshots on the main actor.
///
/// Polls never overlap: the next one starts `interval` after the previous one finished, so a slow herdr can't pile up
/// subprocesses. The fetch itself runs off the main actor.
@MainActor
final class HerdrPoller {
    private static let logger = Logger(subsystem: "cz.jsyrovy.buddr", category: "herdr")

    private let interval: Duration
    private let fetch: @Sendable () async -> HerdrSnapshot
    private let sleep: @Sendable (Duration) async throws -> Void
    private let onUpdate: @MainActor (HerdrSnapshot) -> Void
    private var task: Task<Void, Never>?
    private var lastSnapshot: HerdrSnapshot?

    /// `fetch` and `sleep` are replaced in tests to drive the loop step by step.
    init(
        interval: Duration = .seconds(2),
        fetch: @escaping @Sendable () async -> HerdrSnapshot = { await HerdrStatusFetcher().fetch() },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onUpdate: @escaping @MainActor (HerdrSnapshot) -> Void
    ) {
        self.interval = interval
        self.fetch = fetch
        self.sleep = sleep
        self.onUpdate = onUpdate
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, fetch, sleep, interval] in
            while !Task.isCancelled {
                let snapshot = await fetch()
                guard let self, !Task.isCancelled else { return }
                self.deliver(snapshot)
                try? await sleep(interval)
            }
        }
    }

    /// Stops polling and waits for the loop to end.
    func stop() async {
        guard let task else { return }
        self.task = nil
        task.cancel()
        await task.value
    }

    /// Forwards only snapshots that differ from the previous one, and logs what changed.
    private func deliver(_ snapshot: HerdrSnapshot) {
        guard snapshot != lastSnapshot else { return }
        if snapshot.failures != lastSnapshot?.failures ?? [] {
            if snapshot.failures.isEmpty {
                Self.logger.info("all sources reachable")
            }
            for failure in snapshot.failures {
                Self.logger.error(
                    "\(failure.source?.displayName ?? "herdr", privacy: .public): \(failure.message, privacy: .public)")
            }
        }
        Self.logger.info("status \(snapshot.status.rawValue, privacy: .public), \(snapshot.agents.count) agent(s)")
        lastSnapshot = snapshot
        onUpdate(snapshot)
    }
}
