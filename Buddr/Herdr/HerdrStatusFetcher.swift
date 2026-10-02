import Foundation

/// Collects one `HerdrSnapshot` of a kind of source: discovers the sources and queries all of them concurrently.
///
/// Never throws: every problem ends up in `HerdrSnapshot.failures`, and a failing source doesn't affect the others.
struct HerdrStatusFetcher: Sendable {
    var locator = HerdrLocator()
    var runner: any CommandRunning = ProcessRunner()

    /// Agents of all running local sessions.
    @concurrent
    func fetchSessions() async -> HerdrSnapshot {
        await fetch { client in
            try await client.sessions().filter(\.running).map { .localSession($0.name) }
        }
    }

    /// Agents of all enabled saved machines. herdr connects with SSH batch mode, so a machine that would ask for
    /// authentication fails (or times out) instead of waiting for input.
    @concurrent
    func fetchMachines() async -> HerdrSnapshot {
        await fetch { client in
            try await client.machines().filter(\.enabled).map { .machine(id: $0.id, label: $0.label) }
        }
    }

    private func fetch(discover: (HerdrClient) async throws -> [HerdrSource]) async -> HerdrSnapshot {
        // Resolved on every poll, so installing herdr while Buddr runs just works.
        guard let executable = locator.locate() else {
            return HerdrSnapshot(
                agents: [], failures: [SourceFailure(source: nil, error: HerdrError.executableNotFound)], sources: [])
        }

        let client = HerdrClient(executable: executable, runner: runner)

        let sources: [HerdrSource]
        do {
            sources = try await discover(client)
        } catch {
            return HerdrSnapshot(agents: [], failures: [SourceFailure(source: nil, error: error)], sources: [])
        }

        let results = await withTaskGroup(of: (Int, Result<[AgentRecord], SourceFailure>).self) { group in
            for (index, source) in sources.enumerated() {
                group.addTask { (index, await Self.fetchAgents(of: source, client: client)) }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }

        // Keep the order of the discovery, so snapshots are stable between polls.
        var snapshot = HerdrSnapshot(agents: [], failures: [], sources: sources)
        for (_, result) in results.sorted(by: { $0.0 < $1.0 }) {
            switch result {
            case .success(let agents): snapshot.agents += agents
            case .failure(let failure): snapshot.failures.append(failure)
            }
        }
        return snapshot
    }

    private static func fetchAgents(
        of source: HerdrSource, client: HerdrClient
    ) async -> Result<[AgentRecord], SourceFailure> {
        async let agents = client.agents(on: source)
        // Workspace labels are cosmetic: without them, agents are shown with their workspace IDs.
        async let workspaces = try? client.workspaces(on: source)
        do {
            return .success(AgentRecord.join(try await agents, workspaces: await workspaces ?? [], source: source))
        } catch {
            return .failure(SourceFailure(source: source, error: error))
        }
    }
}

extension AgentRecord {
    /// Combines `agent list` with `workspace list` of the same source.
    static func join(_ agents: [HerdrAgent], workspaces: [HerdrWorkspace], source: HerdrSource) -> [AgentRecord] {
        let workspaces = Dictionary(workspaces.map { ($0.workspaceId, $0) }, uniquingKeysWith: { first, _ in first })
        return agents.map { agent in
            let workspace = workspaces[agent.workspaceId]
            return AgentRecord(
                source: source,
                workspaceID: agent.workspaceId,
                workspace: workspace?.label ?? agent.workspaceId,
                workspaceNumber: workspace?.number,
                paneID: agent.paneId,
                agent: agent.agent,
                status: agent.agentStatus,
                title: agent.terminalTitleStripped ?? agent.terminalTitle ?? "",
                cwd: agent.foregroundCwd ?? agent.cwd)
        }
    }
}

extension SourceFailure {
    init(source: HerdrSource?, error: any Error) {
        self.init(source: source, message: String(describing: error))
    }
}
