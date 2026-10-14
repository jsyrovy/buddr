/// Follows the agents that wait for the user (`blocked` or `done`) from snapshot to snapshot: tells when one newly
/// gets into such a status, and picks the agent for the name plate – of the agents in the shown status, the one that
/// got into it last.
///
/// herdr has no timestamps, and `state_change_seq` can't be compared between sources, so the tracker numbers the
/// arrivals itself: every agent gets an increasing number when it first shows up as `blocked` or `done` (keyed by
/// source, pane and status), and loses it once it is gone – an agent that leaves and comes back, also with a source
/// that is back after a failure, is new. Agents arriving in the same snapshot are ordered by `state_change_seq`, then
/// by their order in the snapshot.
struct AttentionTracker {
    private var arrivals: [Key: Int] = [:]
    private var nextArrival = 0
    /// Whether the last `update` saw an agent newly `blocked` or `done`.
    private(set) var hasNewArrivals = false

    private struct Key: Hashable {
        let source: HerdrSource
        let paneID: String
        let status: AgentStatus

        init(_ agent: AgentRecord) {
            source = agent.source
            paneID = agent.paneID
            status = agent.status
        }
    }

    /// Records the arrivals in `snapshot` and returns the plate for the aggregated `status`; `nil` unless the status
    /// is `blocked` or `done` and an agent is in it.
    mutating func update(with snapshot: HerdrSnapshot, status: AgentStatus) -> NamePlate? {
        let waiting = snapshot.agents.filter(\.status.needsAttention)
        let present = Set(waiting.map(Key.init))
        arrivals = arrivals.filter { present.contains($0.key) }
        let newcomers = waiting.enumerated()
            .filter { arrivals[Key($0.element)] == nil }
            .sorted { ($0.element.stateChangeSeq ?? 0, $0.offset) < ($1.element.stateChangeSeq ?? 0, $1.offset) }
        for (_, agent) in newcomers {
            arrivals[Key(agent)] = nextArrival
            nextArrival += 1
        }
        hasNewArrivals = !newcomers.isEmpty

        guard status.needsAttention else { return nil }
        let shown = waiting.filter { $0.status == status }
        // Every waiting agent has an arrival number by now.
        guard let newest = shown.max(by: { arrivals[Key($0)]! < arrivals[Key($1)]! }) else { return nil }
        return NamePlate(agent: newest, more: shown.count - 1)
    }
}
