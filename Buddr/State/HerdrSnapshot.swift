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
    let workspace: String
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

    static let empty = HerdrSnapshot(agents: [], failures: [])

    /// The snapshots of independently polled sources as one. A failure reported by several parts (such as a missing
    /// herdr) is kept once.
    static func combining(_ parts: [HerdrSnapshot]) -> HerdrSnapshot {
        var failures: [SourceFailure] = []
        for failure in parts.flatMap(\.failures) where !failures.contains(failure) {
            failures.append(failure)
        }
        return HerdrSnapshot(agents: parts.flatMap(\.agents), failures: failures)
    }

    /// Aggregated state shown by the sheep; `unknown` when there are no agents.
    var status: AgentStatus {
        AgentStatus.aggregate(agents.map(\.status))
    }
}
