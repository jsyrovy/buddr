/// The agents of a snapshot grouped for the menu bar list: one section per source (this Mac's sessions, then the
/// machines, in the order of discovery), and within it one group per workspace.
struct AgentOverview: Equatable, Sendable {
    struct Section: Identifiable, Equatable, Sendable {
        let source: HerdrSource
        let title: String
        /// Why the source could not be queried; it has no workspaces then.
        let failure: String?
        let workspaces: [WorkspaceGroup]

        var id: HerdrSource { source }
    }

    struct WorkspaceGroup: Identifiable, Equatable, Sendable {
        struct ID: Hashable, Sendable {
            let source: HerdrSource
            let workspaceID: String
        }

        /// More idle agents than this in one workspace are folded into a single row.
        static let idleFoldLimit = 3

        let id: ID
        let label: String
        /// In the order of `agent list`.
        let agents: [AgentRecord]

        var idleCount: Int { agents.count { $0.status == .idle } }

        var foldsIdleAgents: Bool { idleCount > Self.idleFoldLimit }

        /// The agents shown while the idle ones are folded.
        var activeAgents: [AgentRecord] { agents.filter { $0.status != .idle } }
    }

    struct StatusCount: Equatable, Sendable {
        let status: AgentStatus
        let count: Int
    }

    let sections: [Section]
    /// Failures before any source was known, such as a missing herdr.
    let generalFailures: [String]
    /// Number of agents per status, most urgent first; statuses without agents are left out.
    let statusCounts: [StatusCount]

    init(_ snapshot: HerdrSnapshot) {
        let localSessions = snapshot.sources.count { if case .localSession = $0 { true } else { false } }

        sections = snapshot.sources.map { source in
            Section(
                source: source,
                title: Self.title(of: source, alone: localSessions == 1),
                failure: snapshot.failures.first { $0.source == source }?.message,
                workspaces: Self.workspaces(of: snapshot.agents.filter { $0.source == source }))
        }
        generalFailures = snapshot.failures.filter { $0.source == nil }.map(\.message)
        statusCounts = AgentStatus.allCases.sorted(by: >).compactMap { status in
            let count = snapshot.agents.count { $0.status == status }
            return count > 0 ? StatusCount(status: status, count: count) : nil
        }
    }

    /// "This Mac" for the only local session, otherwise with the session name; machines by their label.
    private static func title(of source: HerdrSource, alone: Bool) -> String {
        switch source {
        case .localSession(let name): alone ? "This Mac" : "This Mac · \(name)"
        case .machine(_, let label): label
        }
    }

    /// Workspaces in herdr's sidebar order; ones without a number after them, in the order of their first agent.
    private static func workspaces(of agents: [AgentRecord]) -> [WorkspaceGroup] {
        var seen: Set<String> = []
        let firsts = agents.filter { seen.insert($0.workspaceID).inserted }
        // The offset keeps the first-appearance order among equal numbers (`sorted` is not stable).
        func rank(_ entry: (offset: Int, element: AgentRecord)) -> (Int, Int) {
            (entry.element.workspaceNumber ?? .max, entry.offset)
        }
        return firsts.enumerated().sorted { rank($0) < rank($1) }.map { _, first in
            WorkspaceGroup(
                id: WorkspaceGroup.ID(source: first.source, workspaceID: first.workspaceID), label: first.workspace,
                agents: agents.filter { $0.workspaceID == first.workspaceID })
        }
    }
}

extension AgentRecord {
    /// The terminal title, or the last component of the working directory, or the pane ID.
    var displayTitle: String {
        if !title.isEmpty { return title }
        if let cwd, let name = cwd.split(separator: "/").last { return String(name) }
        return paneID
    }
}
