#if DEBUG
    import SwiftUI

    /// The orange debug box in the menu bar list (`DebugControls`). Debug builds only.
    struct DebugSection: View {
        @Environment(DebugControls.self) private var controls

        private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

        var body: some View {
            @Bindable var controls = controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DEBUG")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Toggle("Long Name", isOn: $controls.longNamePlate)
                        .toggleStyle(.checkbox)
                    Picker("Status", selection: $controls.statusOverride) {
                        Text("herdr").tag(AgentStatus?.none)
                        ForEach(AgentStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(AgentStatus?.some(status))
                        }
                    }
                    .fixedSize()
                }
                LazyVGrid(columns: Self.columns, spacing: 4) {
                    ForEach(SheepSprites.allClips, id: \.name) { item in
                        Button {
                            controls.play(item.clip)
                        } label: {
                            Text(item.name)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                HStack {
                    Toggle("Loop", isOn: $controls.loops)
                    Toggle("Mirrored", isOn: $controls.mirrored)
                    Spacer()
                    Button("Stop Clip") {
                        controls.stopClip()
                    }
                }
                .toggleStyle(.checkbox)
                HStack {
                    Button("Run Away") {
                        controls.sendAway(startled: true)
                    }
                    Button("Wander Off") {
                        controls.sendAway(startled: false)
                    }
                    Spacer()
                    Button("Come Back") {
                        controls.callBack()
                    }
                }
            }
            .controlSize(.small)
            .padding(8)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.orange.opacity(0.7)))
        }
    }
#endif
