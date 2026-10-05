/// When the sheep leaves the screen on its own: after a while of calm, until something happens.
enum HideMode: String, CaseIterable, Sendable {
    /// Always on the screen.
    case never
    /// Hides while no agent does anything.
    case whenIdle
    /// Hides while no agent waits for the user, even while agents work.
    case unlessNeeded

    /// Whether the aggregated `status` lets the sheep hide (or stay hidden). `unknown` (no agents, or herdr not
    /// running) counts as calm.
    func isCalm(_ status: AgentStatus) -> Bool {
        switch self {
        case .never: false
        case .whenIdle: status == .idle || status == .unknown
        case .unlessNeeded: status != .blocked && status != .done
        }
    }
}
