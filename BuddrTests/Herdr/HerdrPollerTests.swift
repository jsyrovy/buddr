import Testing
import os

@testable import Buddr

@MainActor
struct HerdrPollerTests {
    /// Answers polls with the given snapshots in order; after the last one, a poll runs until it is cancelled.
    final class ScriptedFetch: Sendable {
        /// Reports every poll when it starts.
        let calls: AsyncStream<Void>
        private let callsContinuation: AsyncStream<Void>.Continuation
        private let state: OSAllocatedUnfairLock<(count: Int, snapshots: [HerdrSnapshot])>

        init(_ snapshots: [HerdrSnapshot]) {
            (calls, callsContinuation) = AsyncStream.makeStream(of: Void.self)
            state = OSAllocatedUnfairLock(initialState: (0, snapshots))
        }

        var count: Int {
            state.withLock { $0.count }
        }

        func callAsFunction() async -> HerdrSnapshot {
            let snapshot = state.withLock { state in
                state.count += 1
                return state.snapshots.isEmpty ? nil : state.snapshots.removeFirst()
            }
            callsContinuation.yield()
            if let snapshot {
                return snapshot
            }
            // Never fires, so this returns once the poll is cancelled. The result differs from every scripted
            // snapshot, so delivering it would show up in the updates.
            await OneShotSignal().wait()
            return .empty
        }
    }

    @MainActor
    final class Recorder {
        var snapshots: [HerdrSnapshot] = []
    }

    private static let interval = Duration.seconds(2)
    private static let working = HerdrSnapshot(agents: [.stub(.working)], failures: [])
    private static let blocked = HerdrSnapshot(agents: [.stub(.blocked)], failures: [])
    private static let failure = HerdrSnapshot(
        agents: [], failures: [SourceFailure(source: nil, message: "herdr executable not found")])

    private let sleeper = ManualSleeper()
    private let delivered = Recorder()

    private func poller(_ fetch: ScriptedFetch) -> HerdrPoller {
        HerdrPoller(
            interval: Self.interval, fetch: fetch.callAsFunction, sleep: sleeper.sleep(for:),
            onUpdate: { [delivered] in delivered.snapshots.append($0) })
    }

    @Test func forwardsOnlySnapshotsThatChanged() async {
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

        #expect(delivered.snapshots == [Self.working, Self.failure, Self.blocked])
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
}
