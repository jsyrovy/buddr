// Decodable shapes of herdr CLI output. Only the fields Buddr uses are declared; see CLAUDE.md for the full shapes.

/// `herdr session list --json`
struct HerdrSessionList: Decodable, Sendable {
    let sessions: [HerdrSession]
}

struct HerdrSession: Decodable, Sendable, Equatable {
    let name: String
    let running: Bool
    let isDefault: Bool
    let socketPath: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case running
        case isDefault = "default"
        case socketPath
    }
}

/// Envelope of socket API responses printed by `herdr … agent list` and friends.
struct HerdrResponse<Result: Decodable & Sendable>: Decodable, Sendable {
    let id: String?
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
    let tabId: String
    let workspaceId: String
    let focused: Bool
    let cwd: String?
    let foregroundCwd: String?
    let terminalTitle: String?
    let terminalTitleStripped: String?
}

/// `result` of `workspace list`
struct HerdrWorkspaceList: Decodable, Sendable {
    let workspaces: [HerdrWorkspace]
}

struct HerdrWorkspace: Decodable, Sendable, Equatable {
    let workspaceId: String
    let label: String
    let number: Int
    let focused: Bool
    let agentStatus: AgentStatus
}
