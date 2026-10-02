import Foundation

/// Collects one `HerdrSnapshot`: discovers the running local sessions and queries all of them concurrently.
///
/// Never throws: every problem ends up in `HerdrSnapshot.failures`, and a failing source doesn't affect the others.
struct HerdrStatusFetcher: Sendable {
    var locator = HerdrLocator()
    var runner: any CommandRunning = ProcessRunner()
    /// Timeout of a single herdr command against a local session.
    var localTimeout: Duration = .seconds(5)

    @concurrent
    func fetch() async -> HerdrSnapshot {
        // Resolved on every poll, so installing herdr while Buddr runs just works.
        guard let executable = locator.locate() else {
            return HerdrSnapshot(
                agents: [], failures: [SourceFailure(source: nil, error: HerdrError.executableNotFound)])
        }
        let client = HerdrClient(executable: executable, runner: runner, timeout: localTimeout)

        let sources: [HerdrSource]
        do {
            sources = try await client.sessions().filter(\.running).map { .localSession($0.name) }
        } catch {
            return HerdrSnapshot(agents: [], failures: [SourceFailure(source: nil, error: error)])
        }

        let results = await withTaskGroup(of: (Int, Result<[AgentRecord], SourceFailure>).self) { group in
            for (index, source) in sources.enumerated() {
                group.addTask { (index, await Self.fetchAgents(of: source, client: client)) }
            }
            var results: [Int: Result<[AgentRecord], SourceFailure>] = [:]
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }

        // Keep the order of `session list`, so snapshots are stable between polls.
        var snapshot = HerdrSnapshot.empty
        for index in sources.indices {
            switch results[index] {
            case .success(let agents): snapshot.agents += agents
            case .failure(let failure): snapshot.failures.append(failure)
            case nil: break
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
        let labels = Dictionary(workspaces.map { ($0.workspaceId, $0.label) }, uniquingKeysWith: { first, _ in first })
        return agents.map { agent in
            AgentRecord(
                source: source,
                workspace: labels[agent.workspaceId] ?? agent.workspaceId,
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
