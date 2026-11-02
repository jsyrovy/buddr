import Foundation

/// Collects one `HerdrSnapshot` of herdr-core with one `terminal.list`: this Mac, then the machines added to the core,
/// in its order.
///
/// Never throws: every problem ends up in `HerdrSnapshot.failures`. Only terminals with a reported status count as
/// agents; shells and other programs report none.
struct CoreStatusFetcher: Sendable {
    var transport: any CoreTransport = UnixSocketTransport(path: CoreLocator().socketPath)

    /// A core that is not running is a failure of this Mac. A machine that is not connected is a failure without
    /// agents.
    @concurrent
    func fetch() async -> HerdrSnapshot {
        let local = AgentSource.core(machine: nil)
        let list: CoreTerminalList
        do {
            list = try await CoreClient(transport: transport).terminals()
        } catch {
            return HerdrSnapshot(agents: [], failures: [SourceFailure(source: local, error: error)], sources: [local])
        }
        var snapshot = HerdrSnapshot(agents: [], failures: [], sources: [local])
        for machine in list.machines ?? [] {
            let source = AgentSource.core(machine: machine.name)
            snapshot.sources.append(source)
            if machine.state != "connected" {
                let state = machine.state.replacing("_", with: " ")
                snapshot.failures.append(
                    SourceFailure(source: source, message: machine.why.map { "\(state): \($0)" } ?? state))
            }
        }
        let failed = Set(snapshot.failures.compactMap(\.source))
        snapshot.agents = list.terminals.compactMap(AgentRecord.init).filter { !failed.contains($0.source) }
        return snapshot
    }

    /// `rohan` for `rohan/t7`, `nil` for a terminal on this Mac.
    static func machine(of address: String) -> String? {
        address.firstIndex(of: "/").map { String(address[..<$0]) }
    }
}

extension AgentRecord {
    /// The agent in a herdr-core terminal; `nil` when the terminal reports no status. The workspace comes from the
    /// labels herdr-app sets, else it is the last component of the working directory.
    init?(_ terminal: CoreTerminal) {
        guard let status = terminal.status else { return nil }
        let cwd = terminal.foreground?.cwd ?? terminal.cwd
        let labels = terminal.labels ?? [:]
        // `where` is `workspace / tab`.
        let workspace =
            labels["where"].map { place in
                place.range(of: " / ", options: .backwards).map { String(place[..<$0.lowerBound]) } ?? place
            }
            ?? cwd?.split(separator: "/").last.map(String.init) ?? terminal.address
        self.init(
            source: .core(machine: CoreStatusFetcher.machine(of: terminal.address)),
            workspaceID: labels["herdr.space"] ?? workspace,
            workspace: workspace,
            workspaceNumber: nil,
            paneID: terminal.address,
            agent: status.app,
            status: AgentStatus(coreState: status.state),
            title: terminal.title ?? "",
            cwd: cwd,
            statusOrder: terminal.statusMs)
    }
}

extension AgentStatus {
    /// A herdr-core status word. `error` (the program stopped on an error and needs a person) counts as `blocked`;
    /// words added by future versions as `unknown`.
    init(coreState: String) {
        self = coreState == "error" ? .blocked : AgentStatus(rawValue: coreState) ?? .unknown
    }
}
