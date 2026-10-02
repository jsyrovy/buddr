import os

/// Watches all kinds of herdr sources and reports their combined snapshot on the main actor when it changes.
///
/// Every feed has its own `HerdrPoller` and interval, so a slow or unreachable machine never delays the local
/// sessions. A feed contributes nothing until its first poll has finished.
@MainActor
final class HerdrMonitor {
    /// Local sessions every 2 s, saved machines every 15 s.
    static var defaultFeeds: [HerdrPoller.Feed] {
        let fetcher = HerdrStatusFetcher()
        return [
            .init(interval: .seconds(2), fetch: { await fetcher.fetchSessions() }),
            .init(interval: .seconds(15), fetch: { await fetcher.fetchMachines() }),
        ]
    }

    private static let logger = Logger(subsystem: "cz.jsyrovy.buddr", category: "herdr")

    private let onUpdate: @MainActor (HerdrSnapshot) -> Void
    // Assigned once; a `var` because the pollers' callbacks capture `self`.
    private var pollers: [HerdrPoller] = []
    /// The latest snapshot of every feed, in feed order.
    private var parts: [HerdrSnapshot]
    private var lastSnapshot: HerdrSnapshot?

    init(feeds: [HerdrPoller.Feed] = HerdrMonitor.defaultFeeds, onUpdate: @escaping @MainActor (HerdrSnapshot) -> Void)
    {
        self.onUpdate = onUpdate
        parts = Array(repeating: .empty, count: feeds.count)
        pollers = feeds.enumerated().map { index, feed in
            HerdrPoller(feed) { [weak self] snapshot in
                self?.update(feed: index, with: snapshot)
            }
        }
    }

    func start() {
        for poller in pollers {
            poller.start()
        }
    }

    /// Stops all feeds and waits for their loops to end.
    func stop() async {
        await withDiscardingTaskGroup { group in
            for poller in pollers {
                group.addTask { await poller.stop() }
            }
        }
    }

    private func update(feed index: Int, with snapshot: HerdrSnapshot) {
        parts[index] = snapshot
        let combined = HerdrSnapshot.combining(parts)
        guard combined != lastSnapshot else { return }
        log(combined)
        lastSnapshot = combined
        onUpdate(combined)
    }

    /// Logs the status, and the failures when they changed.
    private func log(_ snapshot: HerdrSnapshot) {
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
    }
}
