import Testing

@testable import Buddr

struct AttentionTrackerTests {
    private static let devbox = HerdrSource.machine(id: "m1", label: "Devbox")

    private static func snapshot(_ agents: AgentRecord...) -> HerdrSnapshot {
        HerdrSnapshot(agents: agents, failures: [])
    }

    // MARK: Name plate

    @Test(arguments: [AgentStatus.working, .idle, .unknown])
    func onlyBlockedAndDoneShowAPlate(status: AgentStatus) {
        var tracker = AttentionTracker()
        let snapshot = Self.snapshot(.stub(status, pane: "p1"), .stub(.done, pane: "p2"), .stub(.blocked, pane: "p3"))
        #expect(tracker.update(with: snapshot, status: status) == nil)
    }

    @Test func noPlateWithoutAnAgentInTheShownStatus() {
        // The shown status may be overridden (debug) and differ from the agents'.
        var tracker = AttentionTracker()
        #expect(tracker.update(with: Self.snapshot(.stub(.done)), status: .blocked) == nil)
        #expect(tracker.update(with: .empty, status: .done) == nil)
    }

    @Test func agentsInALowerStatusAreNotMentioned() {
        var tracker = AttentionTracker()
        let snapshot = Self.snapshot(
            .stub(.done, pane: "p1", title: "finished"), .stub(.blocked, pane: "p2", title: "asking"),
            .stub(.working, pane: "p3"))
        #expect(
            tracker.update(with: snapshot, status: .blocked)
                == NamePlate(machine: nil, workspace: "buddr", title: "asking", more: 0))
    }

    @Test func theNewestArrivalWinsAcrossPolls() {
        var tracker = AttentionTracker()
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
        var tracker = AttentionTracker()
        let snapshot = Self.snapshot(
            .stub(.done, pane: "p1", title: "late", seq: 30), .stub(.done, pane: "p2", title: "early", seq: 10),
            .stub(.done, pane: "p3", title: "middle", seq: 20))
        #expect(tracker.update(with: snapshot, status: .done)?.title == "late")

        var unnumbered = AttentionTracker()
        let withoutNumbers = Self.snapshot(
            .stub(.done, pane: "p1", title: "first"), .stub(.done, pane: "p2", title: "last"))
        #expect(unnumbered.update(with: withoutNumbers, status: .done)?.title == "last")
    }

    @Test func anAgentThatLeavesAndComesBackCountsAsNew() {
        var tracker = AttentionTracker()
        let a = AgentRecord.stub(.done, pane: "p1", title: "a")
        let b = AgentRecord.stub(.done, pane: "p2", title: "b")
        #expect(tracker.update(with: Self.snapshot(a), status: .done)?.title == "a")
        #expect(tracker.update(with: Self.snapshot(a, b), status: .done)?.title == "b")
        // `a` works again, then is done again: it arrived after `b`.
        _ = tracker.update(with: Self.snapshot(.stub(.working, pane: "p1"), b), status: .done)
        #expect(tracker.update(with: Self.snapshot(a, b), status: .done)?.title == "a")
    }

    @Test func aStatusChangeBetweenBlockedAndDoneIsANewArrival() {
        var tracker = AttentionTracker()
        let a = AgentRecord.stub(.done, pane: "p1", title: "a")
        let b = AgentRecord.stub(.done, pane: "p2", title: "b")
        _ = tracker.update(with: Self.snapshot(a), status: .done)
        _ = tracker.update(with: Self.snapshot(a, .stub(.blocked, pane: "p2", title: "b")), status: .blocked)
        #expect(tracker.update(with: Self.snapshot(a, b), status: .done)?.title == "b")
    }

    @Test func countsTheOtherAgentsInTheShownStatus() {
        var tracker = AttentionTracker()
        let snapshot = Self.snapshot(
            .stub(.blocked, pane: "p1"), .stub(.blocked, pane: "p2"), .stub(.blocked, source: Self.devbox, pane: "p1"),
            .stub(.done, pane: "p4"))
        #expect(tracker.update(with: snapshot, status: .blocked)?.more == 2)
    }

    // MARK: New arrivals

    @Test func agentsNewlyBlockedOrDoneAreNewArrivals() {
        let before = Self.snapshot(.stub(.blocked, pane: "p1"), .stub(.working, pane: "p2"))
        let machine = HerdrSource.machine(id: "m1", label: "Devbox")
        let changes = [
            // Another agent blocked, or a waiting one done.
            Self.snapshot(.stub(.blocked, pane: "p1"), .stub(.blocked, pane: "p2")),
            Self.snapshot(.stub(.done, pane: "p1"), .stub(.working, pane: "p2")),
            // An agent that wasn't there, also one in a pane of the same ID on another source.
            Self.snapshot(.stub(.blocked, pane: "p1"), .stub(.working, pane: "p2"), .stub(.done, source: machine)),
        ]
        for after in changes {
            var tracker = AttentionTracker()
            _ = tracker.update(with: before, status: before.status)
            _ = tracker.update(with: after, status: after.status)
            #expect(tracker.hasNewArrivals, "\(after.agents.map(\.status))")
        }
        var tracker = AttentionTracker()
        _ = tracker.update(with: before, status: before.status)
        #expect(tracker.hasNewArrivals)
    }

    @Test func otherChangesAreNoNewArrivals() {
        let before = Self.snapshot(.stub(.blocked, pane: "p1"), .stub(.working, pane: "p2"))
        let changes = [
            before,
            Self.snapshot(.stub(.blocked, pane: "p1"), .stub(.idle, pane: "p2")),
            Self.snapshot(.stub(.working, pane: "p2")),
            .empty,
        ]
        for after in changes {
            var tracker = AttentionTracker()
            _ = tracker.update(with: before, status: before.status)
            _ = tracker.update(with: after, status: after.status)
            #expect(!tracker.hasNewArrivals, "\(after.agents.map(\.status))")
        }
    }
}
