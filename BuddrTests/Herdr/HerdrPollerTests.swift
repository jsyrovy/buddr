import Testing

@testable import Buddr

@MainActor
struct HerdrPollerTests {
    private static let interval = Duration.seconds(2)
    private static let working = HerdrSnapshot(agents: [.stub(.working)], failures: [])
    private static let blocked = HerdrSnapshot(agents: [.stub(.blocked)], failures: [])
    private static let failure = HerdrSnapshot(
        agents: [], failures: [SourceFailure(source: nil, message: "herdr executable not found")])

    private let sleeper = ManualSleeper()
    private let delivered = SnapshotRecorder()

    private func poller(_ fetch: ScriptedFetch) -> HerdrPoller {
        HerdrPoller(.init(interval: Self.interval, fetch: fetch.callAsFunction, sleep: sleeper.sleep(for:))) {
            [delivered] in delivered.snapshots.append($0)
        }
    }

    @Test func forwardsEverySnapshotAndSleepsBetweenPolls() async {
        let fetch = ScriptedFetch([Self.working, Self.working, Self.failure, Self.failure, Self.blocked])
        let poller = poller(fetch)
        var sleeps = sleeper.sleeps.makeAsyncIterator()

        poller.start()
        for poll in 1...5 {
            #expect(await sleeps.next() == Self.interval)
            // Polls don't overlap: the next one starts only after the sleep.
            #expect(fetch.count == poll)
            if poll < 5 {
                sleeper.wake()
            }
        }
        await poller.stop()

        // Unchanged snapshots are filtered by `HerdrMonitor`, after combining the feeds.
        #expect(delivered.snapshots == [Self.working, Self.working, Self.failure, Self.failure, Self.blocked])
    }

    @Test func stopDiscardsAPollThatIsStillRunning() async {
        let fetch = ScriptedFetch([Self.working])
        let poller = poller(fetch)
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var calls = fetch.calls.makeAsyncIterator()

        poller.start()
        _ = await sleeps.next()
        sleeper.wake()
        // The first poll and the second one, which never ends on its own.
        _ = await calls.next()
        _ = await calls.next()
        await poller.stop()

        #expect(delivered.snapshots == [Self.working])
        #expect(fetch.count == 2)
    }

    @Test func stopEndsTheSleepBetweenPolls() async {
        let fetch = ScriptedFetch([Self.working, Self.blocked])
        let poller = poller(fetch)
        var sleeps = sleeper.sleeps.makeAsyncIterator()

        poller.start()
        _ = await sleeps.next()
        await poller.stop()

        #expect(delivered.snapshots == [Self.working])
        #expect(fetch.count == 1)
    }

    @Test func refreshCutsTheSleepBetweenPollsShort() async {
        let fetch = ScriptedFetch([Self.working, Self.blocked])
        let poller = poller(fetch)
        var sleeps = sleeper.sleeps.makeAsyncIterator()

        poller.start()
        _ = await sleeps.next()
        poller.refresh()
        // The next poll ran without `wake()`, and the loop sleeps the full interval again.
        #expect(await sleeps.next() == Self.interval)
        await poller.stop()

        #expect(fetch.count == 2)
        #expect(delivered.snapshots == [Self.working, Self.blocked])
    }

    @Test func refreshDoesNotStartASecondPollWhileOneRuns() async {
        let fetch = ScriptedFetch([Self.working])
        let poller = poller(fetch)
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var calls = fetch.calls.makeAsyncIterator()

        poller.refresh()
        poller.start()
        _ = await sleeps.next()
        sleeper.wake()
        _ = await calls.next()
        _ = await calls.next()
        poller.refresh()
        await poller.stop()

        #expect(fetch.count == 2)
    }
}
