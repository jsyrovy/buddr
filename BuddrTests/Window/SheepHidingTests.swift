import Testing

@testable import Buddr

@MainActor
struct SheepHidingTests {
    private static let delay = Duration.seconds(300)
    private static let shorterDelay = Duration.seconds(60)

    private let sleeper = ManualSleeper()
    private let hiding: SheepHiding
    private let changes: AsyncStream<Bool>

    init() {
        hiding = SheepHiding(sleep: sleeper.sleep(for:))
        let (changes, continuation) = AsyncStream.makeStream(of: Bool.self)
        self.changes = changes
        hiding.onChange = { continuation.yield($0) }
    }

    @Test func hidesAfterTheDelayOfCalm() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()

        // The status before the first snapshot is `unknown`, which is calm: the countdown starts with the settings.
        hiding.setMode(.whenIdle, after: Self.delay)
        #expect(await sleeps.next() == Self.delay)
        #expect(!hiding.isHidden)
        sleeper.wake()

        #expect(await changes.next() == true)
        #expect(hiding.isHidden)
    }

    @Test func neverCountsDownInModeNever() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()

        hiding.setMode(.never, after: Self.shorterDelay)
        hiding.setStatus(.idle)
        hiding.restartCountdown()
        hiding.setMode(.whenIdle, after: Self.delay)

        // Nothing slept before the mode allowed hiding.
        #expect(await sleeps.next() == Self.delay)
    }

    @Test func statusThatIsNotCalmBringsTheSheepBackAtOnce() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        hiding.setMode(.whenIdle, after: Self.delay)
        _ = await sleeps.next()
        sleeper.wake()
        _ = await changes.next()

        hiding.setStatus(.working)

        #expect(await changes.next() == false)
        #expect(!hiding.isHidden)
        // Calm again: a new countdown.
        hiding.setStatus(.idle)
        #expect(await sleeps.next() == Self.delay)
    }

    @Test func cancelledCountdownDoesNotHide() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        hiding.setMode(.whenIdle, after: Self.delay)
        _ = await sleeps.next()

        hiding.setStatus(.working)
        hiding.setStatus(.idle)

        // The new countdown sleeps only after the cancelled one has ended.
        #expect(await sleeps.next() == Self.delay)
        #expect(!hiding.isHidden)
    }

    @Test func changesRestartTheCountdown() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        hiding.setMode(.unlessNeeded, after: Self.delay)
        _ = await sleeps.next()

        // A change between two calm statuses.
        hiding.setStatus(.working)
        #expect(await sleeps.next() == Self.delay)
        // Petting.
        hiding.restartCountdown()
        #expect(await sleeps.next() == Self.delay)
        // The settings.
        hiding.setMode(.unlessNeeded, after: Self.shorterDelay)
        #expect(await sleeps.next() == Self.shorterDelay)
        sleeper.wake()

        #expect(await changes.next() == true)
    }

    @Test func staysHiddenWhileCalm() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        hiding.setMode(.unlessNeeded, after: Self.delay)
        _ = await sleeps.next()
        sleeper.wake()
        _ = await changes.next()

        hiding.setStatus(.working)
        hiding.restartCountdown()
        hiding.setMode(.unlessNeeded, after: Self.shorterDelay)
        #expect(hiding.isHidden)

        // Back only when an agent waits for the user; none of the calls above started a countdown.
        hiding.setStatus(.blocked)
        #expect(await changes.next() == false)
        hiding.setStatus(.idle)
        #expect(await sleeps.next() == Self.shorterDelay)
    }

    @Test func modeNeverBringsTheSheepBack() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        hiding.setMode(.whenIdle, after: Self.delay)
        _ = await sleeps.next()
        sleeper.wake()
        _ = await changes.next()

        hiding.setMode(.never, after: Self.delay)

        #expect(await changes.next() == false)
        #expect(!hiding.isHidden)
    }

    @Test func showCallsTheSheepBackUntilAnotherDelayOfCalm() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        hiding.setMode(.whenIdle, after: Self.delay)
        _ = await sleeps.next()
        sleeper.wake()
        _ = await changes.next()

        hiding.show()

        #expect(await changes.next() == false)
        #expect(!hiding.isHidden)
        #expect(await sleeps.next() == Self.delay)
        sleeper.wake()
        #expect(await changes.next() == true)
    }

    @Test func showDoesNothingWhileTheSheepIsThere() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        hiding.setMode(.whenIdle, after: Self.delay)
        _ = await sleeps.next()

        hiding.show()
        sleeper.wake()

        // The first change is the hiding: `show()` neither reported anything nor restarted the countdown.
        #expect(await changes.next() == true)
    }
}
