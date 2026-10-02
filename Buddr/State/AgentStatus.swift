/// Status of a single herdr agent, as reported in `agent_status`.
enum AgentStatus: String, Sendable, CaseIterable {
    case idle
    case working
    /// Waiting for the user.
    case blocked
    /// Finished and not yet seen by the user.
    case done
    case unknown

    /// Higher wins when several agents are aggregated into one state.
    var urgency: Int {
        switch self {
        case .blocked: 4
        case .done: 3
        case .working: 2
        case .idle: 1
        case .unknown: 0
        }
    }

    /// The most urgent status (blocked > done > working > idle > unknown); `unknown` when there are no agents.
    static func aggregate(_ statuses: some Sequence<AgentStatus>) -> AgentStatus {
        statuses.max { $0.urgency < $1.urgency } ?? .unknown
    }
}

extension AgentStatus: Decodable {
    /// Statuses added by future herdr versions decode as `unknown` instead of failing the whole response.
    init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = AgentStatus(rawValue: rawValue) ?? .unknown
    }
}
