import Foundation
import Testing

@testable import Buddr

struct HerdrClientTests {
    private func client(_ responses: [String: FakeCommandRunner.Response]) -> HerdrClient {
        HerdrClient(
            executable: URL(fileURLWithPath: "/opt/homebrew/bin/herdr"), runner: FakeCommandRunner(responses),
            timeout: .seconds(5))
    }

    @Test func listsSessions() async throws {
        let client = client(["session list --json": try .fixture("session-list-multiple")])
        #expect(try await client.sessions().map(\.name) == ["default", "side", "work"])
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
