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
        let snapshot = await fetcher(runner).fetch()

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
        let snapshot = await fetcher(runner).fetch()

        #expect(snapshot.agents.map(\.source) == [.localSession("work")])
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
        let snapshot = await fetcher(runner).fetch()

        #expect(snapshot.failures.isEmpty)
        #expect(snapshot.agents.map(\.workspace) == ["wG"])
    }

    @Test func sessionsAreQueriedConcurrently() async throws {
        let delay = Duration.milliseconds(400)
        let runner = FakeCommandRunner([
            "session list --json": try .fixture("session-list-multiple"),
            "--session default agent list": try .fixture("agent-list", delay: delay),
            "--session default workspace list": try .fixture("workspace-list", delay: delay),
            "--session work agent list": try .fixture("agent-list", delay: delay),
            "--session work workspace list": try .fixture("workspace-list", delay: delay),
        ])
        let clock = ContinuousClock()
        let start = clock.now
        let snapshot = await fetcher(runner).fetch()
        let elapsed = clock.now - start

        #expect(snapshot.agents.count == 2)
        // Four commands of 400 ms each; sequentially this would take 1.6 s.
        #expect(elapsed < .milliseconds(1_200))
    }

    @Test func missingHerdrIsAFailureWithoutAgents() async {
        let runner = FakeCommandRunner([:])
        let snapshot = await fetcher(runner, herdrInstalled: false).fetch()

        #expect(snapshot.agents.isEmpty)
        #expect(snapshot.failures == [SourceFailure(source: nil, error: HerdrError.executableNotFound)])
        #expect(snapshot.status == .unknown)
        #expect(runner.recordedCalls.isEmpty)
    }

    @Test func failingSessionListIsAFailureWithoutAgents() async {
        let runner = FakeCommandRunner(["session list --json": .failure(exitStatus: 1, stderr: "nope")])
        let snapshot = await fetcher(runner).fetch()

        #expect(snapshot.agents.isEmpty)
        #expect(snapshot.failures.count == 1)
        #expect(snapshot.failures.first?.source == nil)
    }

    @Test func noRunningSessionsMeansNoAgents() async throws {
        let stopped = Data(#"{"sessions":[{"default":true,"name":"default","running":false}]}"#.utf8)
        let runner = FakeCommandRunner(["session list --json": .stdout(stopped)])
        let snapshot = await fetcher(runner).fetch()

        #expect(snapshot == .empty)
        #expect(runner.recordedCalls == ["session list --json"])
    }
}
