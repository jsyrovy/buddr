@testable import Buddr

extension AgentRecord {
    /// An agent in the given state; the other fields don't matter for the test.
    static func stub(_ status: AgentStatus, source: HerdrSource = .localSession("default")) -> AgentRecord {
        AgentRecord(
            source: source, workspace: "buddr", paneID: "p1", agent: "claude", status: status, title: "claude",
            cwd: nil)
    }
}
