import Testing

@testable import Buddr

@MainActor
struct BuddyTurnsTests {
    private static let interval = Duration.seconds(1_800)
    private static let shorterInterval = Duration.seconds(900)

    private let sleeper = ManualSleeper()
    private let turns: BuddyTurns
    private let changes: AsyncStream<BuddyID>

    init() {
        turns = BuddyTurns(current: .sheep, sleep: sleeper.sleep(for:))
        let (changes, continuation) = AsyncStream.makeStream(of: BuddyID.self)
        self.changes = changes
        turns.onChange = { continuation.yield($0) }
    }

    @Test func nextBuddyFollowsTheMenuOrderAndWrapsAround() {
        let all = BuddyID.allCases
        #expect(all.map(\.next) == Array(all.dropFirst()) + [all[0]])
    }

    @Test(arguments: [BuddyChoice.one(.sheep), .one(.blackSheep), .takingTurns])
    func choiceIsSavedAsItsRawValue(choice: BuddyChoice) {
        #expect(BuddyChoice(rawValue: choice.rawValue) == choice)
    }

    @Test func unknownRawValueIsNoChoice() {
        #expect(BuddyChoice(rawValue: "unicorn") == nil)
    }

    @Test func chosenBuddyShowsAtOnce() async {
        var changes = changes.makeAsyncIterator()

        turns.setChoice(.one(.sheep), every: Self.interval)
        turns.setChoice(.one(.blackSheep), every: Self.interval)

        // The sheep was there already.
        #expect(await changes.next() == .blackSheep)
        #expect(turns.current == .blackSheep)
    }

    @Test func takingTurnsShowsTheNextBuddyAfterEveryTurn() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()

        turns.setChoice(.takingTurns, every: Self.interval)
        var expected = BuddyID.sheep
        for _ in 0..<BuddyID.allCases.count + 1 {
            #expect(await sleeps.next() == Self.interval)
            sleeper.wake()
            expected = expected.next
            #expect(await changes.next() == expected)
            #expect(turns.current == expected)
        }
    }

    @Test func turnEndsOnlyWhileNoAgentNeedsTheUser() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        turns.setStatus(.blocked)
        turns.setChoice(.takingTurns, every: Self.interval)

        _ = await sleeps.next()
        sleeper.wake()
        while !turns.isTurnOver {
            await Task.yield()
        }
        turns.setStatus(.done)
        #expect(turns.current == .sheep)

        // Agents may work: calm enough. The change starts the next turn.
        turns.setStatus(.working)
        #expect(await changes.next() == .sheep.next)
        #expect(!turns.isTurnOver)
        #expect(await sleeps.next() == Self.interval)
    }

    @Test func choosingABuddyEndsTakingTurns() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        var changes = changes.makeAsyncIterator()
        turns.setChoice(.takingTurns, every: Self.interval)
        _ = await sleeps.next()

        turns.setChoice(.one(.blackSheep), every: Self.interval)
        #expect(await changes.next() == .blackSheep)

        // Taking turns again starts a whole turn of the buddy on the screen.
        turns.setChoice(.takingTurns, every: Self.interval)
        #expect(await sleeps.next() == Self.interval)
        sleeper.wake()
        #expect(await changes.next() == BuddyID.blackSheep.next)
    }

    @Test func newIntervalStartsTheTurnAgain() async {
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        turns.setChoice(.takingTurns, every: Self.interval)
        #expect(await sleeps.next() == Self.interval)

        turns.setChoice(.takingTurns, every: Self.shorterInterval)
        #expect(await sleeps.next() == Self.shorterInterval)
    }
}
