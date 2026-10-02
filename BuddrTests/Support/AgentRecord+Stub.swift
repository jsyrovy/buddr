@testable import Buddr

extension AgentRecord {
    /// An agent in the given state; the other fields don't matter for the test unless given.
    static func stub(
        _ status: AgentStatus, source: HerdrSource = .localSession("default"), workspace: String = "buddr",
        number: Int? = nil, pane: String = "p1", agent: String? = "claude", title: String = "claude", cwd: String? = nil
    ) -> AgentRecord {
        AgentRecord(
            source: source, workspaceID: "id-\(workspace)", workspace: workspace, workspaceNumber: number,
            paneID: pane, agent: agent, status: status, title: title, cwd: cwd)
    }
}
