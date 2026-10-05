import Testing

@testable import Buddr

struct HerdrSnapshotTests {
    @Test func localSessionsAreNamedAfterTheSession() {
        #expect(HerdrSource.localSession("default").displayName == "local/default")
        #expect(HerdrSource.localSession("work").displayName == "local/work")
    }

    @Test func machinesAreNamedAfterTheirLabel() {
        #expect(HerdrSource.machine(id: "3f9c2a7e", label: "Devbox").displayName == "Devbox")
    }

    @Test func combiningConcatenatesThePartsAndKeepsRepeatedFailuresOnce() {
        let pi = HerdrSource.machine(id: "m2", label: "Pi")
        let missing = SourceFailure(source: nil, message: "herdr not found")
        let devbox = HerdrSource.machine(id: "m1", label: "Devbox")
        let local = HerdrSnapshot(agents: [.stub(.idle)], failures: [missing], sources: [.localSession("default")])
        let machines = HerdrSnapshot(
            agents: [.stub(.blocked, source: devbox)],
            failures: [missing, SourceFailure(source: pi, message: "timed out")], sources: [devbox, pi])
        let combined = HerdrSnapshot.combining([local, machines])

        #expect(combined.agents == local.agents + machines.agents)
        #expect(combined.sources == [.localSession("default"), devbox, pi])
        #expect(combined.failures == [missing, SourceFailure(source: pi, message: "timed out")])
        #expect(combined.status == .blocked)
        #expect(HerdrSnapshot.combining([]) == .empty)
    }

    @Test func statusAggregatesTheAgents() {
        #expect(HerdrSnapshot.empty.status == .unknown)
        #expect(HerdrSnapshot(agents: [.stub(.idle), .stub(.done)], failures: []).status == .done)
    }

    @Test func agentsNewlyBlockedOrDoneNeedAttention() {
        let before = HerdrSnapshot(agents: [.stub(.blocked, pane: "p1"), .stub(.working, pane: "p2")], failures: [])

        // Another agent blocked, or a waiting one done.
        let secondBlocked = HerdrSnapshot(
            agents: [.stub(.blocked, pane: "p1"), .stub(.blocked, pane: "p2")], failures: [])
        #expect(secondBlocked.hasAgentsNewlyNeedingAttention(since: before))
        let firstDone = HerdrSnapshot(agents: [.stub(.done, pane: "p1"), .stub(.working, pane: "p2")], failures: [])
        #expect(firstDone.hasAgentsNewlyNeedingAttention(since: before))
        // An agent that wasn't there, also one in a pane of the same ID on another source.
        let machine = HerdrSource.machine(id: "m1", label: "Devbox")
        let appeared = HerdrSnapshot(agents: before.agents + [.stub(.done, source: machine, pane: "p1")], failures: [])
        #expect(appeared.hasAgentsNewlyNeedingAttention(since: before))
        #expect(HerdrSnapshot(agents: [.stub(.blocked)], failures: []).hasAgentsNewlyNeedingAttention(since: .empty))
    }

    @Test func otherChangesNeedNoAttention() {
        let before = HerdrSnapshot(agents: [.stub(.blocked, pane: "p1"), .stub(.working, pane: "p2")], failures: [])

        #expect(!before.hasAgentsNewlyNeedingAttention(since: before))
        let idle = HerdrSnapshot(agents: [.stub(.blocked, pane: "p1"), .stub(.idle, pane: "p2")], failures: [])
        #expect(!idle.hasAgentsNewlyNeedingAttention(since: before))
        let blockedGone = HerdrSnapshot(agents: [.stub(.working, pane: "p2")], failures: [])
        #expect(!blockedGone.hasAgentsNewlyNeedingAttention(since: before))
        #expect(!HerdrSnapshot.empty.hasAgentsNewlyNeedingAttention(since: before))
    }
}
