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
        let local = HerdrSnapshot(agents: [.stub(.idle)], failures: [missing])
        let machines = HerdrSnapshot(
            agents: [.stub(.blocked, source: .machine(id: "m1", label: "Devbox"))],
            failures: [missing, SourceFailure(source: pi, message: "timed out")])
        let combined = HerdrSnapshot.combining([local, machines])

        #expect(combined.agents == local.agents + machines.agents)
        #expect(combined.failures == [missing, SourceFailure(source: pi, message: "timed out")])
        #expect(combined.status == .blocked)
        #expect(HerdrSnapshot.combining([]) == .empty)
    }

    @Test func statusAggregatesTheAgents() {
        #expect(HerdrSnapshot.empty.status == .unknown)
        #expect(HerdrSnapshot(agents: [.stub(.idle), .stub(.done)], failures: []).status == .done)
    }
}
