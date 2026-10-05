import SwiftUI

/// Content of the menu bar window: all agents grouped by source and workspace, the settings and "Quit".
///
/// Information only – the rows can't be clicked to focus an agent.
struct AgentListView: View {
    let store: SnapshotStore
    @Bindable var preferences: Preferences
    /// Called when the list is shown, to poll right away.
    let onOpen: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snapshot = store.snapshot {
                let overview = AgentOverview(snapshot)
                Text(Self.summary(overview.statusCounts))
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Divider()
                OverviewList(overview: overview)
            } else {
                Text("Loading…")
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                AnimationSettings(preferences: preferences)
                HStack {
                    Toggle("Watch Remote Machines", isOn: $preferences.watchesRemoteMachines)
                        .toggleStyle(.checkbox)
                    Spacer()
                    Button("Quit Buddr") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        // A `MenuBarExtra` window calls `onAppear` every time it opens (checked in the running app).
        .onAppear(perform: onOpen)
    }

    /// "1 blocked · 2 working", or "No agents".
    private static func summary(_ counts: [AgentOverview.StatusCount]) -> String {
        counts.isEmpty ? "No agents" : counts.map { "\($0.count) \($0.status.rawValue)" }.joined(separator: " · ")
    }
}

/// "Animation: Off / On Change / Always", and how long after a change in the `onChange` mode.
private struct AnimationSettings: View {
    @Bindable var preferences: Preferences

    var body: some View {
        HStack {
            Picker("Animation", selection: $preferences.animationMode) {
                ForEach(AnimationMode.allCases, id: \.self) { mode in
                    Text(Self.title(mode)).tag(mode)
                }
            }
            .fixedSize()
            if preferences.animationMode == .onChange {
                Picker("Animated for", selection: $preferences.animationSeconds) {
                    ForEach(Preferences.animationSecondsChoices, id: \.self) { seconds in
                        Text(Self.title(seconds: seconds)).tag(seconds)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private static func title(_ mode: AnimationMode) -> String {
        switch mode {
        case .off: "Off"
        case .onChange: "On Change"
        case .always: "Always"
        }
    }

    /// "for 5 s", "for 1 min".
    private static func title(seconds: Int) -> String {
        seconds.isMultiple(of: 60) ? "for \(seconds / 60) min" : "for \(seconds) s"
    }
}

/// The sections, as tall as their content up to `maxHeight`; taller lists scroll.
private struct OverviewList: View {
    let overview: AgentOverview

    private static let maxHeight: CGFloat = 480

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            sections
                .padding(12)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
        }
        .frame(height: min(contentHeight, Self.maxHeight))
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(overview.generalFailures, id: \.self) { message in
                FailureRow(message: message)
            }
            ForEach(overview.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let failure = section.failure {
                        FailureRow(message: failure)
                    } else if section.workspaces.isEmpty {
                        Text("No agents")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(section.workspaces) { workspace in
                        WorkspaceView(workspace: workspace)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkspaceView: View {
    let workspace: AgentOverview.WorkspaceGroup

    @State private var unfolded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workspace.label)
                .font(.callout.weight(.semibold))
            let folded = workspace.foldsIdleAgents && !unfolded
            ForEach(folded ? workspace.activeAgents : workspace.agents, id: \.paneID) { agent in
                AgentRow(agent: agent)
            }
            if workspace.foldsIdleAgents {
                Button {
                    unfolded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: folded ? "chevron.right" : "chevron.down")
                            .frame(width: 14)
                        Text(folded ? "\(workspace.idleCount) idle" : "Fold idle")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 4)
    }
}

private struct AgentRow: View {
    let agent: AgentRecord

    var body: some View {
        HStack(spacing: 6) {
            StatusIcon(status: agent.status)
            Text(agent.displayTitle)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text([agent.agent, agent.status.rawValue].compactMap(\.self).joined(separator: " · "))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .font(.callout)
        .help(agent.cwd ?? agent.displayTitle)
    }
}

/// A status told apart by shape as well as by color.
private struct StatusIcon: View {
    let status: AgentStatus

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
            .frame(width: 14)
            .accessibilityLabel(status.rawValue)
    }

    private var symbol: String {
        switch status {
        case .blocked: "exclamationmark.circle.fill"
        case .done: "checkmark.circle.fill"
        case .working: "ellipsis.circle.fill"
        case .idle: "circle"
        case .unknown: "questionmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case .blocked: .red
        case .done: .green
        case .working: .blue
        case .idle, .unknown: .secondary
        }
    }
}

private struct FailureRow: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        }
        .help(message)
    }
}
