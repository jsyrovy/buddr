import Testing

@testable import Buddr

@MainActor
struct HerdrMonitorTests {
    private static let local = HerdrSnapshot(agents: [.stub(.working)], failures: [])
    private static let localBlocked = HerdrSnapshot(agents: [.stub(.blocked)], failures: [])
    private static let machine = HerdrSnapshot(
        agents: [.stub(.done, source: .herdr(.machine(id: "m1", label: "Devbox")))],
        failures: [SourceFailure(source: .herdr(.machine(id: "m2", label: "Pi")), message: "timed out")])
    private static let localAndMachine = HerdrSnapshot(
        agents: local.agents + machine.agents, failures: machine.failures)
    private static let machineBlocked = HerdrSnapshot(
        agents: [.stub(.blocked, source: .herdr(.machine(id: "m1", label: "Devbox")))], failures: [])
    private static let missingHerdr = HerdrSnapshot(
        agents: [], failures: [SourceFailure(source: nil, error: HerdrError.executableNotFound)])

    private let localSleeper = ManualSleeper()
    private let machineSleeper = ManualSleeper()
    private let delivered = SnapshotRecorder()

    private func monitor(local: ScriptedFetch, machines: ScriptedFetch) -> HerdrMonitor {
        HerdrMonitor(
            feeds: [
                .localSessions: .init(
                    interval: .seconds(2), fetch: local.callAsFunction, sleep: localSleeper.sleep(for:)),
                .machines: .init(
                    interval: .seconds(15), fetch: machines.callAsFunction, sleep: machineSleeper.sleep(for:)),
            ],
            onUpdate: { [delivered] in delivered.snapshots.append($0) })
    }

    @Test func combinesTheFeedsInFeedOrder() async {
        let monitor = monitor(local: ScriptedFetch([Self.local]), machines: ScriptedFetch([Self.machine]))
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        #expect(await localSleeps.next() == .seconds(2))
        #expect(await machineSleeps.next() == .seconds(15))
        await monitor.stop()

        // Whichever feed finishes first is shown on its own until the other one arrives.
        #expect(delivered.snapshots.count == 2)
        #expect(delivered.snapshots.last == Self.localAndMachine)
        #expect(delivered.snapshots.last?.status == .done)
    }

    @Test func hangingFeedDoesNotDelayTheOthers() async {
        let machines = ScriptedFetch([])
        let monitor = monitor(local: ScriptedFetch([Self.local, Self.localBlocked]), machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        _ = await localSleeps.next()
        localSleeper.wake()
        _ = await localSleeps.next()
        await monitor.stop()

        #expect(delivered.snapshots == [Self.local, Self.localBlocked])
        #expect(machines.count == 1)
    }

    @Test func unchangedSnapshotsAreNotDeliveredAgain() async {
        let monitor = monitor(
            local: ScriptedFetch([Self.local, Self.local, Self.localBlocked]), machines: ScriptedFetch([]))
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        for _ in 1...2 {
            _ = await localSleeps.next()
            localSleeper.wake()
        }
        _ = await localSleeps.next()
        await monitor.stop()

        #expect(delivered.snapshots == [Self.local, Self.localBlocked])
    }

    @Test func failureReportedByEveryFeedIsDeliveredOnce() async {
        let monitor = monitor(
            local: ScriptedFetch([Self.missingHerdr]), machines: ScriptedFetch([Self.missingHerdr]))
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        _ = await localSleeps.next()
        _ = await machineSleeps.next()
        await monitor.stop()

        #expect(delivered.snapshots == [Self.missingHerdr])
    }

    @Test func disablingAKindRemovesItsAgentsAndFailuresAtOnce() async {
        let machines = ScriptedFetch([Self.machine, Self.machineBlocked])
        let monitor = monitor(local: ScriptedFetch([Self.local]), machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        _ = await localSleeps.next()
        _ = await machineSleeps.next()
        monitor.setEnabled(false, .machines)

        #expect(delivered.snapshots.last == Self.local)
        await monitor.stop()
        #expect(machines.count == 1)
    }

    @Test func kindDisabledBeforeStartIsPolledOnceEnabled() async {
        let machines = ScriptedFetch([Self.machine])
        let monitor = monitor(local: ScriptedFetch([Self.local]), machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.setEnabled(false, .machines)
        monitor.start()
        _ = await localSleeps.next()
        #expect(machines.count == 0)
        monitor.setEnabled(true, .machines)
        #expect(await machineSleeps.next() == .seconds(15))
        await monitor.stop()

        #expect(delivered.snapshots == [Self.local, Self.localAndMachine])
    }

    @Test func enablingBeforeTheMonitorStartsDoesNotPoll() async {
        let machines = ScriptedFetch([Self.machine])
        let monitor = monitor(local: ScriptedFetch([Self.local]), machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.setEnabled(false, .machines)
        monitor.setEnabled(true, .machines)
        #expect(machines.count == 0)
        monitor.start()
        _ = await localSleeps.next()
        _ = await machineSleeps.next()
        await monitor.stop()

        #expect(machines.count == 1)
    }

    @Test func pollRunningWhenDisabledIsDiscarded() async {
        let machines = ScriptedFetch([])
        let monitor = monitor(local: ScriptedFetch([Self.local]), machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineCalls = machines.calls.makeAsyncIterator()

        monitor.start()
        _ = await localSleeps.next()
        _ = await machineCalls.next()
        monitor.setEnabled(false, .machines)
        await monitor.stop()

        #expect(delivered.snapshots == [Self.local])
    }

    @Test func reenablingRightAwayContinuesPolling() async {
        let machines = ScriptedFetch([Self.machine, Self.machineBlocked])
        let monitor = monitor(local: ScriptedFetch([Self.local]), machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        _ = await localSleeps.next()
        _ = await machineSleeps.next()
        monitor.setEnabled(false, .machines)
        monitor.setEnabled(true, .machines)
        // The new loop starts once the cancelled one has left its sleep, so the two never sleep at once.
        _ = await machineSleeps.next()
        await monitor.stop()

        #expect(machines.count == 2)
        #expect(
            delivered.snapshots.last
                == HerdrSnapshot(agents: Self.local.agents + Self.machineBlocked.agents, failures: []))
    }

    @Test func refreshPollsEveryEnabledKindRightAway() async {
        let local = ScriptedFetch([Self.local, Self.localBlocked])
        let machines = ScriptedFetch([Self.machine, Self.machineBlocked])
        let monitor = monitor(local: local, machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        _ = await localSleeps.next()
        _ = await machineSleeps.next()
        monitor.refresh()
        _ = await localSleeps.next()
        _ = await machineSleeps.next()
        await monitor.stop()

        #expect(local.count == 2)
        #expect(machines.count == 2)
        #expect(
            delivered.snapshots.last
                == HerdrSnapshot(agents: Self.localBlocked.agents + Self.machineBlocked.agents, failures: []))
    }

    @Test func refreshLeavesADisabledKindAlone() async {
        let machines = ScriptedFetch([Self.machine])
        let monitor = monitor(local: ScriptedFetch([Self.local, Self.localBlocked]), machines: machines)
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()

        monitor.setEnabled(false, .machines)
        monitor.start()
        _ = await localSleeps.next()
        monitor.refresh()
        _ = await localSleeps.next()
        await monitor.stop()

        #expect(machines.count == 0)
        #expect(delivered.snapshots == [Self.local, Self.localBlocked])
    }

    @Test func settingsEnableTheKindsOfTheChosenBackends() {
        func enabled(_ backends: Set<Backend>, remote: Bool) -> [HerdrMonitor.SourceKind] {
            HerdrMonitor.SourceKind.allCases.filter { $0.isEnabled(by: backends, watchesRemoteMachines: remote) }
        }
        #expect(enabled([.herdr, .hc], remote: true) == [.localSessions, .machines, .core])
        #expect(enabled([.herdr, .hc], remote: false) == [.localSessions, .core])
        #expect(enabled([.herdr], remote: true) == [.localSessions, .machines])
        #expect(enabled([.herdr], remote: false) == [.localSessions])
        // herdr-core's machines come in the same call; they are filtered, not switched off.
        #expect(enabled([.hc], remote: false) == [.core])
    }

    @Test func withoutRemoteMachinesEveryRemoteSourceIsLeftOutAtOnce() async {
        let rohan = AgentSource.core(machine: "rohan")
        let core = HerdrSnapshot(
            agents: [.stub(.working, source: .core(machine: nil)), .stub(.blocked, source: rohan)],
            failures: [SourceFailure(source: AgentSource.core(machine: "pi"), message: "unreachable")])
        let monitor = monitor(local: ScriptedFetch([core]), machines: ScriptedFetch([Self.machine]))
        var localSleeps = localSleeper.sleeps.makeAsyncIterator()
        var machineSleeps = machineSleeper.sleeps.makeAsyncIterator()

        monitor.start()
        _ = await localSleeps.next()
        _ = await machineSleeps.next()
        monitor.configure(backends: [.herdr, .hc], watchesRemoteMachines: false)
        let local = delivered.snapshots.last
        monitor.configure(backends: [.herdr, .hc], watchesRemoteMachines: true)
        let all = delivered.snapshots.last
        await monitor.stop()

        #expect(local == HerdrSnapshot(agents: [.stub(.working, source: .core(machine: nil))], failures: []))
        #expect(all?.agents == core.agents)
        #expect(all?.failures == core.failures)
    }
}
