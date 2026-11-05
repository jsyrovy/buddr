/// A server that agents are read from: a herdr server, or this Mac's herdr-core (`hc`) and the machines added to it.
/// Keep everything that depends on the kind of source switching over this enum.
enum AgentSource: Hashable, Sendable {
    case herdr(HerdrSource)
    /// herdr-core on this Mac (`machine == nil`), or a machine added to it, by the name it has there.
    case core(machine: String?)

    var backend: Backend {
        switch self {
        case .herdr: .herdr
        case .core: .hc
        }
    }

    var displayName: String {
        switch self {
        case .herdr(let source): source.displayName
        case .core(let machine): machine.map { "hc/\($0)" } ?? "hc"
        }
    }

    /// The machine's name for remote sources, `nil` for this Mac.
    var machineLabel: String? {
        switch self {
        case .herdr(.localSession), .core(machine: nil): nil
        case .herdr(.machine(_, let label)): label
        case .core(let machine?): machine
        }
    }

    var isRemote: Bool {
        machineLabel != nil
    }
}

/// A herdr server: a session on this Mac or a saved machine.
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
    let source: AgentSource
    let workspaceID: String
    /// The workspace label, or its ID when the label is not known.
    let workspace: String
    /// Position of the workspace in herdr's sidebar, if known (never for herdr-core).
    let workspaceNumber: Int?
    /// herdr's pane ID, or the terminal's address in herdr-core (`t7`, `machine/t7`).
    let paneID: String
    /// Agent kind such as `claude`, if herdr detected it (the `app` herdr-core reports, such as `claude-code`).
    let agent: String?
    let status: AgentStatus
    let title: String
    let cwd: String?
    /// Orders the agents of one source by when they got their status: herdr's `state_change_seq`, herdr-core's
    /// `status_ms`. Not comparable between sources.
    let statusOrder: UInt64?
}

/// A source that could not be queried, or a failure before any source was known (`source == nil`).
struct SourceFailure: Error, Hashable, Sendable {
    let source: AgentSource?
    let message: String
}

/// Everything known about the agents after one poll.
struct HerdrSnapshot: Hashable, Sendable {
    var agents: [AgentRecord]
    var failures: [SourceFailure]
    /// Every source that was queried, in the order of discovery – including failed ones and ones without agents.
    var sources: [AgentSource]

    static let empty = HerdrSnapshot(agents: [], failures: [], sources: [])

    /// The snapshots of independently polled sources as one: the sources of this Mac first, then the machines, each
    /// in the order of the parts. A failure reported by several parts (such as a missing herdr) is kept once.
    static func combining(_ parts: [HerdrSnapshot]) -> HerdrSnapshot {
        let sources = parts.flatMap(\.sources)
        return HerdrSnapshot(
            agents: parts.flatMap(\.agents), failures: parts.flatMap(\.failures).uniqued(),
            sources: sources.filter { !$0.isRemote } + sources.filter(\.isRemote))
    }

    /// The snapshot without the remote sources, their agents and failures.
    func withoutRemoteSources() -> HerdrSnapshot {
        HerdrSnapshot(
            agents: agents.filter { !$0.source.isRemote }, failures: failures.filter { $0.source?.isRemote != true },
            sources: sources.filter { !$0.isRemote })
    }

    /// Aggregated state shown by the buddy; `unknown` when there are no agents.
    var status: AgentStatus {
        AgentStatus.aggregate(agents.map(\.status))
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
