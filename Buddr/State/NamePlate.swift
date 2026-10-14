import Foundation

/// What the plate under the sheep says: which agent the sheep reports while it is `blocked` or `done`.
///
/// The text is `[machine · ]workspace · title`, followed by `+N` when more agents are in the same status. Only the
/// title may be shortened to fit (`SheepSprites.Plate.text(for:maxWidth:)`).
struct NamePlate: Equatable, Sendable {
    static let separator = " · "

    /// Machine label (remote sources only) and workspace, always shown.
    let prefix: String
    /// The agent's title; empty when it would only repeat the workspace.
    let title: String
    /// How many other agents are in the same status.
    let more: Int

    var text: String {
        (title.isEmpty ? prefix : prefix + Self.separator + title) + suffix
    }

    /// `+N` for the other agents, or nothing.
    var suffix: String {
        more > 0 ? "  +\(more)" : ""
    }
}

extension NamePlate {
    init(agent: AgentRecord, more: Int) {
        var prefix = agent.workspace
        if case .machine(_, let label) = agent.source {
            prefix = label + Self.separator + prefix
        }
        let title = agent.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(prefix: prefix, title: title == agent.workspace ? "" : title, more: more)
    }
}
