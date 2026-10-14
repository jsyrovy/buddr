import Testing

@testable import Buddr

struct NamePlateTests {
    private static let devbox = HerdrSource.machine(id: "m1", label: "Devbox")

    private static func snapshot(_ agents: AgentRecord...) -> HerdrSnapshot {
        HerdrSnapshot(agents: agents, failures: [])
    }

    // MARK: Which agent

    @Test(arguments: [AgentStatus.working, .idle, .unknown])
    func onlyBlockedAndDoneShowAPlate(status: AgentStatus) {
        var tracker = NamePlateTracker()
        let snapshot = Self.snapshot(.stub(status, pane: "p1"), .stub(.done, pane: "p2"), .stub(.blocked, pane: "p3"))
        #expect(tracker.update(with: snapshot, status: status) == nil)
    }

    @Test func noPlateWithoutAnAgentInTheShownStatus() {
        // The shown status may be overridden (debug) and differ from the agents'.
        var tracker = NamePlateTracker()
        #expect(tracker.update(with: Self.snapshot(.stub(.done)), status: .blocked) == nil)
        #expect(tracker.update(with: .empty, status: .done) == nil)
    }

    @Test func agentsInALowerStatusAreNotMentioned() {
        var tracker = NamePlateTracker()
        let snapshot = Self.snapshot(
            .stub(.done, pane: "p1", title: "finished"), .stub(.blocked, pane: "p2", title: "asking"),
            .stub(.working, pane: "p3"))
        #expect(
            tracker.update(with: snapshot, status: .blocked) == NamePlate(prefix: "buddr", title: "asking", more: 0))
    }

    @Test func theNewestArrivalWinsAcrossPolls() {
        var tracker = NamePlateTracker()
        let first = AgentRecord.stub(.done, pane: "p1", title: "first", seq: 90)
        _ = tracker.update(with: Self.snapshot(first, .stub(.working, pane: "p2")), status: .done)
        // A lower sequence number from another source doesn't matter: the later poll wins.
        let second = AgentRecord.stub(.done, source: Self.devbox, pane: "p2", title: "second", seq: 3)
        let plate = tracker.update(with: Self.snapshot(first, second), status: .done)
        #expect(plate?.title == "second")
        #expect(plate?.more == 1)
        // Order in the snapshot doesn't matter either.
        #expect(tracker.update(with: Self.snapshot(second, first), status: .done)?.title == "second")
    }

    @Test func arrivalsInOnePollAreOrderedBySequenceNumberThenByOrder() {
        var tracker = NamePlateTracker()
        let snapshot = Self.snapshot(
            .stub(.done, pane: "p1", title: "late", seq: 30), .stub(.done, pane: "p2", title: "early", seq: 10),
            .stub(.done, pane: "p3", title: "middle", seq: 20))
        #expect(tracker.update(with: snapshot, status: .done)?.title == "late")

        var unnumbered = NamePlateTracker()
        let withoutNumbers = Self.snapshot(
            .stub(.done, pane: "p1", title: "first"), .stub(.done, pane: "p2", title: "last"))
        #expect(unnumbered.update(with: withoutNumbers, status: .done)?.title == "last")
    }

    @Test func anAgentThatLeavesAndComesBackCountsAsNew() {
        var tracker = NamePlateTracker()
        let a = AgentRecord.stub(.done, pane: "p1", title: "a")
        let b = AgentRecord.stub(.done, pane: "p2", title: "b")
        #expect(tracker.update(with: Self.snapshot(a), status: .done)?.title == "a")
        #expect(tracker.update(with: Self.snapshot(a, b), status: .done)?.title == "b")
        // `a` works again, then is done again: it arrived after `b`.
        _ = tracker.update(with: Self.snapshot(.stub(.working, pane: "p1"), b), status: .done)
        #expect(tracker.update(with: Self.snapshot(a, b), status: .done)?.title == "a")
    }

    @Test func aStatusChangeBetweenBlockedAndDoneIsANewArrival() {
        var tracker = NamePlateTracker()
        let a = AgentRecord.stub(.done, pane: "p1", title: "a")
        let b = AgentRecord.stub(.done, pane: "p2", title: "b")
        _ = tracker.update(with: Self.snapshot(a), status: .done)
        _ = tracker.update(with: Self.snapshot(a, .stub(.blocked, pane: "p2", title: "b")), status: .blocked)
        #expect(tracker.update(with: Self.snapshot(a, b), status: .done)?.title == "b")
    }

    @Test func countsTheOtherAgentsInTheShownStatus() {
        var tracker = NamePlateTracker()
        let snapshot = Self.snapshot(
            .stub(.blocked, pane: "p1"), .stub(.blocked, pane: "p2"), .stub(.blocked, source: Self.devbox, pane: "p1"),
            .stub(.done, pane: "p4"))
        #expect(tracker.update(with: snapshot, status: .blocked)?.more == 2)
    }

    // MARK: Text

    @Test func localAgentsShowTheWorkspaceAndTitle() {
        let plate = NamePlate(agent: .stub(.done, workspace: "buddr", title: "test123"), more: 0)
        #expect(plate == NamePlate(prefix: "buddr", title: "test123", more: 0))
        #expect(plate.text == "buddr · test123")
    }

    @Test func remoteAgentsShowTheMachineFirst() {
        let plate = NamePlate(agent: .stub(.done, source: Self.devbox, workspace: "api", title: "fix-login"), more: 2)
        #expect(plate.prefix == "Devbox · api")
        #expect(plate.text == "Devbox · api · fix-login  +2")
    }

    @Test func theTitleFallsBackToTheWorkingDirectoryThenThePane() {
        let byDirectory = NamePlate(agent: .stub(.done, title: "", cwd: "/Users/me/code/website"), more: 0)
        #expect(byDirectory.title == "website")
        let byPane = NamePlate(agent: .stub(.done, pane: "wG:p3", title: ""), more: 0)
        #expect(byPane.title == "wG:p3")
    }

    @Test func aTitleRepeatingTheWorkspaceIsDropped() {
        let plate = NamePlate(agent: .stub(.done, workspace: "buddr", title: "", cwd: "/Users/me/code/buddr"), more: 1)
        #expect(plate.title == "")
        #expect(plate.text == "buddr  +1")
    }

    @Test func surroundingWhitespaceOfTheTitleIsTrimmed() {
        #expect(NamePlate(agent: .stub(.done, title: "  fix login\n"), more: 0).title == "fix login")
    }
}
