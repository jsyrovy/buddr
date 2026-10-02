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
    /// The latest loop; once cancelled, it may still be finishing its fetch.
    private var loop: Task<Void, Never>?
    /// Whether the loop waits between two polls; `refresh()` restarts it then.
    private var isSleeping = false

    init(_ feed: Feed, onUpdate: @escaping @MainActor (HerdrSnapshot) -> Void) {
        self.feed = feed
        self.onUpdate = onUpdate
    }

    /// Starts polling right away. Does nothing if already running.
    func start() {
        guard loop?.isCancelled != false else { return }
        loop = Task { [weak self, feed, previous = loop] in
            // A cancelled loop may still be ending; two loops never run at once.
            await previous?.value
            while !Task.isCancelled {
                let snapshot = await feed.fetch()
                guard let self, !Task.isCancelled else { return }
                self.onUpdate(snapshot)
                self.isSleeping = true
                try? await feed.sleep(feed.interval)
                self.isSleeping = false
            }
        }
    }

    /// Polls right away if the loop is sleeping between polls: the sleeping loop is replaced by a new one, which
    /// starts with a poll. Does nothing while a poll runs (its result is about to arrive) or when not running.
    func refresh() {
        guard isSleeping, loop?.isCancelled == false else { return }
        cancel()
        start()
    }

    /// Stops polling without waiting: nothing is reported after this returns, a running fetch is cancelled and the
    /// loop ends shortly after. `start()` may be called again right away.
    func cancel() {
        loop?.cancel()
    }

    /// Stops polling and waits for the loop to end.
    func stop() async {
        cancel()
        await loop?.value
    }
}
