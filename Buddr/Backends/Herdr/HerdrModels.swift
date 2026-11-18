// Decodable shapes of herdr CLI output. Only the fields Buddr uses are declared; see CLAUDE.md for the full shapes.

/// `herdr session list --json`
struct HerdrSessionList: Decodable, Sendable {
    let sessions: [HerdrSession]
}

struct HerdrSession: Decodable, Sendable, Equatable {
    let name: String
    let running: Bool
}

/// An entry of `herdr machine list --json` (a top-level array).
struct HerdrMachine: Decodable, Sendable, Equatable {
    let id: String
    let label: String
    let enabled: Bool
}

/// Envelope of socket API responses printed by `herdr … agent list` and friends.
struct HerdrResponse<Result: Decodable & Sendable>: Decodable, Sendable {
    let result: Result?
    let error: HerdrErrorBody?
}

struct HerdrErrorBody: Decodable, Sendable, Equatable {
    let code: String
    let message: String
}

/// `result` of `agent list`
struct HerdrAgentList: Decodable, Sendable {
    let agents: [HerdrAgent]
}

struct HerdrAgent: Decodable, Sendable, Equatable {
    let agent: String?
    let agentStatus: AgentStatus
    let paneId: String
    let workspaceId: String
    let cwd: String?
    let foregroundCwd: String?
    let terminalTitle: String?
    let terminalTitleStripped: String?
    /// Counter of the agent's status changes, increasing across the whole herdr server (not comparable between
    /// servers). Missing in older herdr versions.
    let stateChangeSeq: UInt64?
}

/// `result` of `workspace list`
struct HerdrWorkspaceList: Decodable, Sendable {
    let workspaces: [HerdrWorkspace]
}

struct HerdrWorkspace: Decodable, Sendable, Equatable {
    let workspaceId: String
    let label: String
    /// Position in herdr's sidebar, starting at 1.
    let number: Int?
}
