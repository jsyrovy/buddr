import Foundation

/// What the plate under the sheep says: which agent the sheep reports while it is `blocked` or `done`.
///
/// The text is `[machine · ]workspace · title`, followed by `+N` when more agents are in the same status. Only the
/// title may be shortened to fit (`PixelFont.truncated(_:maxWidth:)`).
struct NamePlate: Equatable, Sendable {
    static let separator = " · "

    /// Machine label (remote sources only) and workspace, always shown.
    let prefix: String
    /// The agent's title; empty when it would only repeat the workspace.
    let title: String
    /// How many other agents are in the same status.
    let more: Int

    init(prefix: String, title: String, more: Int) {
        self.prefix = prefix
        self.title = title
        self.more = more
    }

    init(agent: AgentRecord, more: Int) {
        var prefix = agent.workspace
        if case .machine(_, let label) = agent.source {
            prefix = label + Self.separator + prefix
        }
        let title = agent.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(prefix: prefix, title: title == agent.workspace ? "" : title, more: more)
    }

    /// The whole text, with `title` in place of the agent's title.
    func text(title: String) -> String {
        (title.isEmpty ? prefix : prefix + Self.separator + title) + suffix
    }

    var text: String {
        text(title: title)
    }

    /// `+N` for the other agents, or nothing.
    var suffix: String {
        more > 0 ? "  +\(more)" : ""
    }
}

/// Picks the agent for the name plate: of the agents in the shown status, the one that got into it last.
///
/// herdr has no timestamps, and `state_change_seq` can't be compared between sources, so the tracker numbers the
/// arrivals itself: every agent gets an increasing number when it first shows up as `blocked` or `done` (an
/// `AttentionKey`), and loses it once it is gone. Agents arriving in the same poll are ordered by `state_change_seq`,
/// then by their order in the snapshot.
struct NamePlateTracker {
    private var arrivals: [AttentionKey: Int] = [:]
    private var nextArrival = 0

    /// Records the arrivals in `snapshot` and returns the plate for the aggregated `status`; `nil` unless the status
    /// is `blocked` or `done` and an agent is in it.
    mutating func update(with snapshot: HerdrSnapshot, status: AgentStatus) -> NamePlate? {
        let waiting = snapshot.agents.filter(\.status.needsAttention)
        let keys = waiting.map(AttentionKey.init)
        let present = Set(keys)
        arrivals = arrivals.filter { present.contains($0.key) }
        let newcomers = keys.indices
            .filter { arrivals[keys[$0]] == nil }
            .sorted { (waiting[$0].stateChangeSeq ?? 0, $0) < (waiting[$1].stateChangeSeq ?? 0, $1) }
        for index in newcomers {
            arrivals[keys[index]] = nextArrival
            nextArrival += 1
        }

        guard status.needsAttention else { return nil }
        let shown = waiting.indices.filter { waiting[$0].status == status }
        guard let newest = shown.max(by: { arrivals[keys[$0], default: 0] < arrivals[keys[$1], default: 0] }) else {
            return nil
        }
        return NamePlate(agent: waiting[newest], more: shown.count - 1)
    }
}
