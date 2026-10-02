import Testing

@testable import Buddr

@MainActor
struct HerdrMonitorTests {
    private static let local = HerdrSnapshot(agents: [.stub(.working)], failures: [])
    private static let localBlocked = HerdrSnapshot(agents: [.stub(.blocked)], failures: [])
    private static let machine = HerdrSnapshot(
        agents: [.stub(.done, source: .machine(id: "m1", label: "Devbox"))],
        failures: [SourceFailure(source: .machine(id: "m2", label: "Pi"), message: "timed out")])
    private static let missingHerdr = HerdrSnapshot(
        agents: [], failures: [SourceFailure(source: nil, error: HerdrError.executableNotFound)])

    private let localSleeper = ManualSleeper()
    private let machineSleeper = ManualSleeper()
    private let delivered = SnapshotRecorder()

    private func monitor(local: ScriptedFetch, machines: ScriptedFetch) -> HerdrMonitor {
        HerdrMonitor(
            feeds: [
                .init(interval: .seconds(2), fetch: local.callAsFunction, sleep: localSleeper.sleep(for:)),
                .init(interval: .seconds(15), fetch: machines.callAsFunction, sleep: machineSleeper.sleep(for:)),
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
        let combined = HerdrSnapshot(agents: Self.local.agents + Self.machine.agents, failures: Self.machine.failures)
        #expect(delivered.snapshots.last == combined)
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
}
