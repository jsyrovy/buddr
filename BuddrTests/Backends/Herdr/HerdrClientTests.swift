import Foundation
import Testing

@testable import Buddr

struct HerdrClientTests {
    private func client(_ runner: FakeCommandRunner) -> HerdrClient {
        HerdrClient(executable: URL(fileURLWithPath: "/opt/homebrew/bin/herdr"), runner: runner)
    }

    private func client(_ responses: [String: FakeCommandRunner.Response]) -> HerdrClient {
        client(FakeCommandRunner(responses))
    }

    @Test func machineCommandsGetALongerTimeoutThanLocalOnes() async throws {
        let devbox = HerdrSource.machine(id: "3f9c2a7e", label: "Devbox")
        let runner = FakeCommandRunner([
            "machine list --json": try .fixture("machine-list"),
            "--session default agent list": try .fixture("agent-list"),
            "--machine 3f9c2a7e agent list": try .fixture("agent-list"),
            "--machine 3f9c2a7e workspace list": try .fixture("workspace-list"),
        ])
        let client = client(runner)
        _ = try await client.machines()
        _ = try await client.agents(on: .localSession("default"))
        _ = try await client.agents(on: devbox)
        _ = try await client.workspaces(on: devbox)

        #expect(
            runner.recordedTimeouts == [
                "machine list --json": .seconds(5),
                "--session default agent list": .seconds(5),
                "--machine 3f9c2a7e agent list": .seconds(15),
                "--machine 3f9c2a7e workspace list": .seconds(15),
            ])
    }

    @Test func listsSessions() async throws {
        let client = client(["session list --json": try .fixture("session-list-multiple")])
        #expect(try await client.sessions().map(\.name) == ["default", "side", "work"])
    }

    @Test func listsMachines() async throws {
        let client = client(["machine list --json": try .fixture("machine-list")])
        #expect(try await client.machines().map(\.label) == ["Devbox", "Pi"])
    }

    @Test func queriesAgentsAndWorkspacesOfAMachineWithoutASession() async throws {
        let devbox = HerdrSource.machine(id: "3f9c2a7e", label: "Devbox")
        let client = client([
            "--machine 3f9c2a7e agent list": try .fixture("agent-list"),
            "--machine 3f9c2a7e workspace list": try .fixture("workspace-list"),
        ])
        #expect(try await client.agents(on: devbox).map(\.paneId) == ["wG:p1"])
        #expect(try await client.workspaces(on: devbox).count == 5)
    }

    @Test func queriesAgentsAndWorkspacesOfALocalSession() async throws {
        let client = client([
            "--session work agent list": try .fixture("agent-list"),
            "--session work workspace list": try .fixture("workspace-list"),
        ])
        #expect(try await client.agents(on: .localSession("work")).map(\.paneId) == ["wG:p1"])
        #expect(try await client.workspaces(on: .localSession("work")).count == 5)
    }

    @Test func errorEnvelopeOnStderrBecomesAPIError() async throws {
        let stderr = String(decoding: try Fixture.data("error"), as: UTF8.self)
        let client = client(["--session default agent list": .failure(exitStatus: 1, stderr: stderr)])
        await #expect(
            throws: HerdrError.api(
                command: "--session default agent list", code: "agent_not_found",
                message: "agent target nonexistent-pane-xyz not found")
        ) {
            try await client.agents(on: .localSession("default"))
        }
    }

    @Test func plainStderrBecomesCommandFailure() async {
        let client = client(["session list --json": .failure(exitStatus: 1, stderr: "server not running\n")])
        await #expect(
            throws: HerdrError.commandFailed(command: "session list", exitStatus: 1, stderr: "server not running")
        ) {
            try await client.sessions()
        }
    }

    @Test func timeoutBecomesHerdrTimeout() async {
        let client = client(["--session default agent list": .error(.timedOut(.seconds(5)))])
        await #expect(throws: HerdrError.timedOut(command: "--session default agent list")) {
            try await client.agents(on: .localSession("default"))
        }
    }

    @Test func launchFailureIsReported() async {
        let client = client(["session list --json": .error(.launchFailed("no such file"))])
        await #expect(throws: HerdrError.launchFailed(command: "session list", reason: "no such file")) {
            try await client.sessions()
        }
    }
}
