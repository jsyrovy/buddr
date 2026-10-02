@testable import Buddr

extension HerdrSnapshot {
    /// A snapshot whose queried sources are those of its agents and failures, in that order.
    init(agents: [AgentRecord], failures: [SourceFailure]) {
        self.init(
            agents: agents, failures: failures,
            sources: (agents.map(\.source) + failures.compactMap(\.source)).uniqued())
    }
}
