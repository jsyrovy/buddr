import Foundation

/// What the plate under the sheep can say: which agent the sheep reports while it is `blocked` or `done`.
///
/// The text (`Label`) is `[machine · ][workspace · ]title`, followed by `+N` when more agents are in the same status.
/// Which of the three parts are shown is set in the menu bar (`Field`). Only the title may be shortened to fit
/// (`SheepSprites.Plate.text(for:maxWidth:)`).
struct NamePlate: Equatable, Sendable {
    static let separator = " · "

    /// A part of the plate that can be switched off in the menu bar.
    enum Field: String, CaseIterable, Sendable {
        case machine
        case workspace
        case title

        static let all = Set(allCases)
    }

    /// Machine label, remote sources only.
    let machine: String?
    let workspace: String
    let title: String
    /// How many other agents are in the same status.
    let more: Int

    /// The text with the `fields` parts; `nil` when they have none (e.g. only the machine of a local agent). The
    /// title is dropped when it would only repeat the shown workspace.
    func label(showing fields: Set<Field>) -> Label? {
        let parts = [fields.contains(.machine) ? machine : nil, fields.contains(.workspace) ? workspace : nil]
        let prefix = parts.compactMap { $0 }.joined(separator: Self.separator)
        let repeatsWorkspace = fields.contains(.workspace) && title == workspace
        let title = fields.contains(.title) && !repeatsWorkspace ? title : ""
        switch (prefix.isEmpty, title.isEmpty) {
        case (true, true): return nil
        case (false, false): return Label(lead: prefix + Self.separator, title: title, more: more)
        default: return Label(lead: prefix, title: title, more: more)
        }
    }

    /// The plate's text.
    struct Label: Equatable, Sendable {
        /// The parts before the title, with the separator when a title follows; never shortened.
        let lead: String
        /// The agent's title, may be empty.
        let title: String
        /// How many other agents are in the same status.
        let more: Int

        var text: String {
            lead + title + suffix
        }

        /// `+N` for the other agents, or nothing.
        var suffix: String {
            more > 0 ? "  +\(more)" : ""
        }
    }
}

extension NamePlate {
    init(agent: AgentRecord, more: Int) {
        var machine: String?
        if case .machine(_, let label) = agent.source {
            machine = label
        }
        self.init(
            machine: machine, workspace: agent.workspace,
            title: agent.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines), more: more)
    }
}
