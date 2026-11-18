import Testing

@testable import Buddr

struct AgentSnapshotTests {
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
        let local = AgentSnapshot(
            agents: [.stub(.idle)], failures: [missing], sources: [.herdr(.localSession("default"))])
        let machines = AgentSnapshot(
            agents: [.stub(.blocked, source: devbox)],
            failures: [missing, SourceFailure(source: pi, message: "timed out")], sources: [devbox, pi])
        let combined = AgentSnapshot.combining([local, machines])

        #expect(combined.agents == local.agents + machines.agents)
        #expect(combined.sources == [.herdr(.localSession("default")), devbox, pi])
        #expect(combined.failures == [missing, SourceFailure(source: pi, message: "timed out")])
        #expect(combined.status == .blocked)
        #expect(AgentSnapshot.combining([]) == .empty)
    }

    @Test func statusAggregatesTheAgents() {
        #expect(AgentSnapshot.empty.status == .unknown)
        #expect(AgentSnapshot(agents: [.stub(.idle), .stub(.done)], failures: []).status == .done)
    }

    @Test func sourcesKnowTheirBackendAndMachine() {
        let local = AgentSource.herdr(.localSession("default"))
        let devbox = AgentSource.herdr(.machine(id: "m1", label: "Devbox"))
        let core = AgentSource.herdrCore(machine: nil)
        let rohan = AgentSource.herdrCore(machine: "rohan")

        #expect([local, devbox, core, rohan].map(\.backend) == [.herdr, .herdr, .hc, .hc])
        #expect([local, devbox, core, rohan].map(\.machineLabel) == [nil, "Devbox", nil, "rohan"])
        #expect([local, devbox, core, rohan].map(\.isRemote) == [false, true, false, true])
        #expect([local, devbox, core, rohan].map(\.displayName) == ["local/default", "Devbox", "hc", "hc/rohan"])
    }

    @Test func combiningPutsThisMacBeforeTheMachines() {
        let devbox = AgentSource.herdr(.machine(id: "m1", label: "Devbox"))
        let herdr = AgentSnapshot(agents: [], failures: [], sources: [.herdr(.localSession("default")), devbox])
        let core = AgentSnapshot(
            agents: [], failures: [], sources: [.herdrCore(machine: nil), .herdrCore(machine: "rohan")])

        #expect(
            AgentSnapshot.combining([herdr, core]).sources == [
                .herdr(.localSession("default")), .herdrCore(machine: nil), devbox, .herdrCore(machine: "rohan"),
            ])
    }

    @Test func remoteSourcesCanBeLeftOut() {
        let devbox = AgentSource.herdr(.machine(id: "m1", label: "Devbox"))
        let missing = SourceFailure(source: nil, message: "herdr not found")
        let snapshot = AgentSnapshot(
            agents: [.stub(.idle), .stub(.blocked, source: devbox)],
            failures: [missing, SourceFailure(source: .herdrCore(machine: "pi"), message: "unreachable")],
            sources: [.herdr(.localSession("default")), devbox, .herdrCore(machine: "pi")])

        #expect(
            snapshot.withoutRemoteSources()
                == AgentSnapshot(
                    agents: [.stub(.idle)], failures: [missing], sources: [.herdr(.localSession("default"))]))
    }

    @Test func backendChoices() {
        #expect(BackendChoice.herdr.backends == [.herdr])
        #expect(BackendChoice.hc.backends == [.hc])
        #expect(BackendChoice.rex.backends == [.rex])
        #expect(BackendChoice.all.backends == [.herdr, .hc, .rex])
    }

    @Test func savedBothMeansAllBackends() {
        // Saved while there were only herdr and hc.
        #expect(BackendChoice(savedValue: "both") == .all)
        #expect(BackendChoice(savedValue: "rex") == .rex)
        #expect(BackendChoice(savedValue: "everything") == nil)
    }

    @Test func rexSources() {
        let local = AgentSource.rex(machine: nil)
        let studio = AgentSource.rex(machine: "studio")

        #expect([local, studio].map(\.backend) == [.rex, .rex])
        #expect([local, studio].map(\.displayName) == ["rex", "rex/studio"])
        #expect([local, studio].map(\.machineLabel) == [nil, "studio"])
        #expect([local, studio].map(\.isRemote) == [false, true])
    }
}
