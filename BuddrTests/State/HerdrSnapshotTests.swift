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
        let pi = AgentSource.herdr(.machine(id: "m2", label: "Pi"))
        let missing = SourceFailure(source: nil, message: "herdr not found")
        let devbox = AgentSource.herdr(.machine(id: "m1", label: "Devbox"))
        let local = HerdrSnapshot(
            agents: [.stub(.idle)], failures: [missing], sources: [.herdr(.localSession("default"))])
        let machines = HerdrSnapshot(
            agents: [.stub(.blocked, source: devbox)],
            failures: [missing, SourceFailure(source: pi, message: "timed out")], sources: [devbox, pi])
        let combined = HerdrSnapshot.combining([local, machines])

        #expect(combined.agents == local.agents + machines.agents)
        #expect(combined.sources == [.herdr(.localSession("default")), devbox, pi])
        #expect(combined.failures == [missing, SourceFailure(source: pi, message: "timed out")])
        #expect(combined.status == .blocked)
        #expect(HerdrSnapshot.combining([]) == .empty)
    }

    @Test func statusAggregatesTheAgents() {
        #expect(HerdrSnapshot.empty.status == .unknown)
        #expect(HerdrSnapshot(agents: [.stub(.idle), .stub(.done)], failures: []).status == .done)
    }

    @Test func sourcesKnowTheirBackendAndMachine() {
        let local = AgentSource.herdr(.localSession("default"))
        let devbox = AgentSource.herdr(.machine(id: "m1", label: "Devbox"))
        let core = AgentSource.core(machine: nil)
        let rohan = AgentSource.core(machine: "rohan")

        #expect([local, devbox, core, rohan].map(\.backend) == [.herdr, .herdr, .hc, .hc])
        #expect([local, devbox, core, rohan].map(\.machineLabel) == [nil, "Devbox", nil, "rohan"])
        #expect([local, devbox, core, rohan].map(\.isRemote) == [false, true, false, true])
        #expect([local, devbox, core, rohan].map(\.displayName) == ["local/default", "Devbox", "hc", "hc/rohan"])
    }

    @Test func combiningPutsThisMacBeforeTheMachines() {
        let devbox = AgentSource.herdr(.machine(id: "m1", label: "Devbox"))
        let herdr = HerdrSnapshot(agents: [], failures: [], sources: [.herdr(.localSession("default")), devbox])
        let core = HerdrSnapshot(agents: [], failures: [], sources: [.core(machine: nil), .core(machine: "rohan")])

        #expect(
            HerdrSnapshot.combining([herdr, core]).sources == [
                .herdr(.localSession("default")), .core(machine: nil), devbox, .core(machine: "rohan"),
            ])
    }

    @Test func remoteSourcesCanBeLeftOut() {
        let devbox = AgentSource.herdr(.machine(id: "m1", label: "Devbox"))
        let missing = SourceFailure(source: nil, message: "herdr not found")
        let snapshot = HerdrSnapshot(
            agents: [.stub(.idle), .stub(.blocked, source: devbox)],
            failures: [missing, SourceFailure(source: .core(machine: "pi"), message: "unreachable")],
            sources: [.herdr(.localSession("default")), devbox, .core(machine: "pi")])

        #expect(
            snapshot.withoutRemoteSources()
                == HerdrSnapshot(
                    agents: [.stub(.idle)], failures: [missing], sources: [.herdr(.localSession("default"))]))
    }

    @Test func backendChoices() {
        #expect(BackendChoice.herdr.backends == [.herdr])
        #expect(BackendChoice.hc.backends == [.hc])
        #expect(BackendChoice.both.backends == [.herdr, .hc])
    }
}
