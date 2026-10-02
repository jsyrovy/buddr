import os

/// Polls herdr periodically and reports changed snapshots on the main actor.
///
/// Polls never overlap: the next one starts `interval` after the previous one finished, so a slow herdr can't pile up
/// subprocesses. The fetch itself runs off the main actor.
@MainActor
final class HerdrPoller {
    private static let logger = Logger(subsystem: "cz.jsyrovy.buddr", category: "herdr")

    private let fetcher: HerdrStatusFetcher
    private let interval: Duration
    private let onUpdate: @MainActor (HerdrSnapshot) -> Void
    private var task: Task<Void, Never>?
    private var lastSnapshot: HerdrSnapshot?

    init(
        fetcher: HerdrStatusFetcher = HerdrStatusFetcher(), interval: Duration = .seconds(2),
        onUpdate: @escaping @MainActor (HerdrSnapshot) -> Void
    ) {
        self.fetcher = fetcher
        self.interval = interval
        self.onUpdate = onUpdate
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, fetcher, interval] in
            while !Task.isCancelled {
                let snapshot = await fetcher.fetch()
                guard let self, !Task.isCancelled else { return }
                self.deliver(snapshot)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
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
