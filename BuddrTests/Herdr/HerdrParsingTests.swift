import Foundation
import Testing

@testable import Buddr

struct HerdrParsingTests {
    @Test func parsesSessionList() throws {
        let sessions = try HerdrClient.parseSessions(Fixture.data("session-list"))
        #expect(
            sessions == [
                HerdrSession(
                    name: "default", running: true, isDefault: true,
                    socketPath: "/Users/me/.config/herdr/herdr.sock")
            ])
    }

    @Test func parsesSessionListWithStoppedSessions() throws {
        let sessions = try HerdrClient.parseSessions(Fixture.data("session-list-multiple"))
        #expect(sessions.map(\.name) == ["default", "side", "work"])
        #expect(sessions.map(\.running) == [true, false, true])
    }

    @Test func parsesAgentList() throws {
        let list: HerdrAgentList = try HerdrClient.parseResult(Fixture.data("agent-list"), command: "agent list")
        let agent = try #require(list.agents.first)
        #expect(list.agents.count == 1)
        #expect(agent.agent == "claude")
        #expect(agent.agentStatus == .working)
        #expect(agent.paneId == "wG:p1")
        #expect(agent.tabId == "wG:t1")
        #expect(agent.workspaceId == "wG")
        #expect(agent.focused)
        #expect(agent.cwd == "/Users/me/code/buddr")
        #expect(agent.foregroundCwd == "/Users/me/code/buddr")
        #expect(agent.terminalTitle == "◑ buddr impl1")
        #expect(agent.terminalTitleStripped == "buddr impl1")
    }

    @Test func parsesAgentsWithMissingOptionalFieldsAndFutureStatuses() throws {
        let list: HerdrAgentList = try HerdrClient.parseResult(Fixture.data("agent-list-mixed"), command: "agent list")
        #expect(list.agents.map(\.agentStatus) == [.working, .blocked, .done, .idle, .unknown])
        let idle = list.agents[3]
        #expect(idle.agent == nil)
        #expect(idle.cwd == nil)
        #expect(idle.terminalTitle == nil)
    }

    @Test func parsesEmptyAgentList() throws {
        let list: HerdrAgentList = try HerdrClient.parseResult(Fixture.data("agent-list-empty"), command: "agent list")
        #expect(list.agents.isEmpty)
    }

    @Test func parsesWorkspaceList() throws {
        let list: HerdrWorkspaceList = try HerdrClient.parseResult(
            Fixture.data("workspace-list"), command: "workspace list")
        #expect(list.workspaces.map(\.label) == ["temp", "notes", "dotfiles", "website", "buddr"])
        #expect(list.workspaces.map(\.number) == [1, 2, 3, 4, 5])
        #expect(list.workspaces.last?.workspaceId == "wG")
        #expect(list.workspaces.last?.agentStatus == .working)
        #expect(list.workspaces.last?.focused == true)
    }

    @Test func errorEnvelopeBecomesAPIError() throws {
        #expect(
            throws: HerdrError.api(
                command: "agent get", code: "agent_not_found",
                message: "agent target nonexistent-pane-xyz not found")
        ) {
            let _: HerdrAgentList = try HerdrClient.parseResult(Fixture.data("error"), command: "agent get")
        }
    }

    @Test func garbageIsInvalidOutput() {
        #expect {
            let _: HerdrAgentList = try HerdrClient.parseResult(Data("not json".utf8), command: "agent list")
        } throws: { error in
            if case HerdrError.invalidOutput(command: "agent list", reason: _) = error { true } else { false }
        }
    }

    @Test func joinUsesWorkspaceLabelsAndFallsBackToIDs() throws {
        let agents: HerdrAgentList = try HerdrClient.parseResult(
            Fixture.data("agent-list-mixed"), command: "agent list")
        let workspaces: HerdrWorkspaceList = try HerdrClient.parseResult(
            Fixture.data("workspace-list"), command: "workspace list")
        let records = AgentRecord.join(
            agents.agents, workspaces: workspaces.workspaces, source: .localSession("default"))

        #expect(records.map(\.workspace) == ["buddr", "dotfiles", "website", "temp", "wZ"])
        #expect(records.map(\.paneID) == ["wG:p1", "wE:p2", "wF:p3", "w7:p4", "wZ:p5"])
        #expect(records.allSatisfy { $0.source == .localSession("default") })
        // Stripped title preferred, raw title as fallback, empty when there is none.
        #expect(records.map(\.title) == ["buddr impl1", "Waiting for approval", "Refactor done", "", "Future status"])
        // Foreground cwd preferred, cwd as fallback.
        #expect(records[2].cwd == "/Users/me/code/website")
        #expect(records[3].cwd == nil)
        #expect(records[3].agent == nil)
    }
}
