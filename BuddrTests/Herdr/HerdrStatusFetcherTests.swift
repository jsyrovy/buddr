import Foundation
import Testing

@testable import Buddr

struct HerdrStatusFetcherTests {
    private func fetcher(_ runner: FakeCommandRunner, herdrInstalled: Bool = true) -> HerdrStatusFetcher {
        HerdrStatusFetcher(
            locator: HerdrLocator(searchPath: "/opt/homebrew/bin", isExecutable: { _ in herdrInstalled }),
            runner: runner)
    }

    @Test func queriesOnlyRunningSessionsAndJoinsWorkspaceLabels() async throws {
        let runner = FakeCommandRunner([
            "session list --json": try .fixture("session-list-multiple"),
            "--session default agent list": try .fixture("agent-list"),
            "--session default workspace list": try .fixture("workspace-list"),
            "--session work agent list": try .fixture("agent-list-mixed"),
            "--session work workspace list": try .fixture("workspace-list"),
        ])
        let snapshot = await fetcher(runner).fetchSessions()

        #expect(snapshot.failures.isEmpty)
        #expect(snapshot.agents.count == 6)
        // Session order of `session list` is kept.
        #expect(snapshot.agents.first?.source == .localSession("default"))
        #expect(snapshot.agents.dropFirst().allSatisfy { $0.source == .localSession("work") })
        #expect(snapshot.agents.first?.workspace == "buddr")
        #expect(snapshot.status == .blocked)
        #expect(!runner.recordedCalls.contains { $0.hasPrefix("--session side") })
    }

    @Test func failingSessionDoesNotAffectTheOthers() async throws {
        let runner = FakeCommandRunner([
            "session list --json": try .fixture("session-list-multiple"),
            "--session default agent list": .error(.timedOut(.seconds(5))),
            "--session default workspace list": try .fixture("workspace-list"),
            "--session work agent list": try .fixture("agent-list"),
            "--session work workspace list": try .fixture("workspace-list"),
        ])
        let snapshot = await fetcher(runner).fetchSessions()

        #expect(snapshot.agents.map(\.source) == [.localSession("work")])
        // The failed session is still listed as queried.
        #expect(snapshot.sources == [.localSession("default"), .localSession("work")])
        #expect(
            snapshot.failures == [
                SourceFailure(source: .localSession("default"), message: "--session default agent list: timed out")
            ])
        #expect(snapshot.status == .working)
    }

    @Test func missingWorkspaceListFallsBackToWorkspaceIDs() async throws {
        let runner = FakeCommandRunner([
            "session list --json": try .fixture("session-list"),
            "--session default agent list": try .fixture("agent-list"),
            "--session default workspace list": .failure(exitStatus: 1, stderr: "boom"),
        ])
        let snapshot = await fetcher(runner).fetchSessions()

        #expect(snapshot.failures.isEmpty)
        #expect(snapshot.agents.map(\.workspace) == ["wG"])
    }

    @Test(.timeLimit(.minutes(1))) func sessionsAreQueriedConcurrently() async throws {
        // Every command waits until all four run at once; querying them one by one would hang until the time limit.
        let barrier = CommandBarrier(count: 4)
        let runner = FakeCommandRunner([
            "session list --json": try .fixture("session-list-multiple"),
            "--session default agent list": try .fixture("agent-list", barrier: barrier),
            "--session default workspace list": try .fixture("workspace-list", barrier: barrier),
            "--session work agent list": try .fixture("agent-list", barrier: barrier),
            "--session work workspace list": try .fixture("workspace-list", barrier: barrier),
        ])
        let snapshot = await fetcher(runner).fetchSessions()

        #expect(snapshot.failures.isEmpty)
        #expect(snapshot.agents.count == 2)
    }

    @Test func missingHerdrIsAFailureWithoutAgents() async {
        let runner = FakeCommandRunner([:])
        let snapshot = await fetcher(runner, herdrInstalled: false).fetchSessions()

        #expect(snapshot.agents.isEmpty)
        #expect(snapshot.failures == [SourceFailure(source: nil, error: HerdrError.executableNotFound)])
        #expect(snapshot.status == .unknown)
        #expect(runner.recordedCalls.isEmpty)
    }

    @Test func failingSessionListIsAFailureWithoutAgents() async {
        let runner = FakeCommandRunner(["session list --json": .failure(exitStatus: 1, stderr: "nope")])
        let snapshot = await fetcher(runner).fetchSessions()

        #expect(snapshot.agents.isEmpty)
        #expect(snapshot.failures.count == 1)
        #expect(snapshot.failures.first?.source == nil)
    }

    @Test func noRunningSessionsMeansNoAgents() async throws {
        let stopped = Data(#"{"sessions":[{"default":true,"name":"default","running":false}]}"#.utf8)
        let runner = FakeCommandRunner(["session list --json": .stdout(stopped)])
        let snapshot = await fetcher(runner).fetchSessions()

        #expect(snapshot == .empty)
        #expect(runner.recordedCalls == ["session list --json"])
    }

    private static let devbox = HerdrSource.machine(id: "3f9c2a7e5b1d4c6a8e0f2b4d6a8c0e1f", label: "Devbox")
    private static let pi = HerdrSource.machine(id: "8a1e4c7b2d5f3a6c9e0b1d4f7a2c5e8b", label: "Pi")

    /// Responses of `agent list` and `workspace list` on `source`; the workspace labels are always the same.
    private static func responses(
        _ source: HerdrSource, agents: FakeCommandRunner.Response
    ) throws -> [String: FakeCommandRunner.Response] {
        let prefix = source.arguments.joined(separator: " ")
        return ["\(prefix) agent list": agents, "\(prefix) workspace list": try .fixture("workspace-list")]
    }

    @Test func queriesOnlyEnabledMachinesWithTheirProfileID() async throws {
        let runner = FakeCommandRunner(
            ["machine list --json": try .fixture("machine-list-mixed")]
                .merging(try Self.responses(Self.devbox, agents: .fixture("agent-list"))) { $1 }
                .merging(try Self.responses(Self.pi, agents: .fixture("agent-list-empty"))) { $1 })
        let snapshot = await fetcher(runner).fetchMachines()

        #expect(snapshot.failures.isEmpty)
        #expect(snapshot.agents.map(\.source) == [Self.devbox])
        // Pi has no agents, but it was queried; the disabled machine was not.
        #expect(snapshot.sources == [Self.devbox, Self.pi])
        #expect(snapshot.agents.first?.workspace == "buddr")
        #expect(snapshot.status == .working)
        #expect(runner.recordedCalls.count == 5)
        #expect(!runner.recordedCalls.contains { $0.contains("--session") })
    }

    @Test func unreachableMachineDoesNotAffectTheOthers() async throws {
        // What herdr prints when SSH batch mode can't authenticate is not known; any failure counts.
        let runner = FakeCommandRunner(
            ["machine list --json": try .fixture("machine-list")]
                .merging(try Self.responses(Self.devbox, agents: .error(.timedOut(.seconds(15))))) { $1 }
                .merging(try Self.responses(Self.pi, agents: .fixture("agent-list-mixed"))) { $1 })
        let snapshot = await fetcher(runner).fetchMachines()

        #expect(snapshot.agents.count == 5)
        #expect(snapshot.agents.allSatisfy { $0.source == Self.pi })
        #expect(
            snapshot.failures == [
                SourceFailure(
                    source: Self.devbox, message: "--machine 3f9c2a7e5b1d4c6a8e0f2b4d6a8c0e1f agent list: timed out")
            ])
    }

    @Test func failingMachineListIsAFailureWithoutAgents() async {
        let runner = FakeCommandRunner(["machine list --json": .failure(exitStatus: 1, stderr: "bad config")])
        let snapshot = await fetcher(runner).fetchMachines()

        #expect(snapshot.agents.isEmpty)
        #expect(
            snapshot.failures == [
                SourceFailure(source: nil, message: "machine list: exit status 1: bad config")
            ])
    }
}
