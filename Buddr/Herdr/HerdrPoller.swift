/// Polls one kind of herdr source periodically and reports every snapshot on the main actor.
///
/// Polls never overlap: the next one starts `interval` after the previous one finished, so a slow herdr can't pile up
/// subprocesses. The fetch itself runs off the main actor.
@MainActor
final class HerdrPoller {
    struct Feed: Sendable {
        let interval: Duration
        let fetch: @Sendable () async -> HerdrSnapshot
        /// Replaced in tests to drive the loop step by step.
        var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    }

    private let feed: Feed
    private let onUpdate: @MainActor (HerdrSnapshot) -> Void
    private var task: Task<Void, Never>?

    init(_ feed: Feed, onUpdate: @escaping @MainActor (HerdrSnapshot) -> Void) {
        self.feed = feed
        self.onUpdate = onUpdate
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, feed] in
            while !Task.isCancelled {
                let snapshot = await feed.fetch()
                guard let self, !Task.isCancelled else { return }
                self.onUpdate(snapshot)
                try? await feed.sleep(feed.interval)
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
}
