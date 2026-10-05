/// A herdr server that agents are read from. Keep everything that depends on the kind of source switching over this
/// enum.
enum HerdrSource: Hashable, Sendable {
    /// A running session on this Mac (`herdr --session <name>`).
    case localSession(String)
    /// An enabled saved SSH machine (`herdr --machine <id>`), in the session saved in its profile.
    case machine(id: String, label: String)

    var displayName: String {
        switch self {
        case .localSession(let name): "local/\(name)"
        case .machine(_, let label): label
        }
    }
}

/// One agent, joined with its workspace label.
struct AgentRecord: Hashable, Sendable {
    let source: HerdrSource
    let workspaceID: String
    /// The workspace label, or its ID when the label is not known.
    let workspace: String
    /// Position of the workspace in herdr's sidebar, if known.
    let workspaceNumber: Int?
    let paneID: String
    /// Agent kind such as `claude`, if herdr detected it.
    let agent: String?
    let status: AgentStatus
    let title: String
    let cwd: String?
}

/// A source that could not be queried, or a failure before any source was known (`source == nil`).
struct SourceFailure: Error, Hashable, Sendable {
    let source: HerdrSource?
    let message: String
}

/// Everything known about herdr agents after one poll.
struct HerdrSnapshot: Hashable, Sendable {
    var agents: [AgentRecord]
    var failures: [SourceFailure]
    /// Every source that was queried, in the order of discovery – including failed ones and ones without agents.
    var sources: [HerdrSource]

    static let empty = HerdrSnapshot(agents: [], failures: [], sources: [])

    /// The snapshots of independently polled sources as one. A failure reported by several parts (such as a missing
    /// herdr) is kept once.
    static func combining(_ parts: [HerdrSnapshot]) -> HerdrSnapshot {
        HerdrSnapshot(
            agents: parts.flatMap(\.agents), failures: parts.flatMap(\.failures).uniqued(),
            sources: parts.flatMap(\.sources))
    }

    /// Aggregated state shown by the sheep; `unknown` when there are no agents.
    var status: AgentStatus {
        AgentStatus.aggregate(agents.map(\.status))
    }

    /// Whether an agent is `blocked` or `done` that wasn't in that status in `previous` – including agents that weren't
    /// there at all, such as those of a source that is back after a failure.
    func hasAgentsNewlyNeedingAttention(since previous: HerdrSnapshot) -> Bool {
        let before = Set(previous.agents.map(AttentionKey.init))
        return agents.contains { $0.status.needsAttention && !before.contains(AttentionKey($0)) }
    }

    private struct AttentionKey: Hashable {
        let source: HerdrSource
        let paneID: String
        let status: AgentStatus

        init(_ agent: AgentRecord) {
            source = agent.source
            paneID = agent.paneID
            status = agent.status
        }
    }
}

extension Array where Element: Equatable {
    /// The elements in their order, each kept only at its first occurrence.
    func uniqued() -> [Element] {
        var result: [Element] = []
        for element in self where !result.contains(element) {
            result.append(element)
        }
        return result
    }
}
