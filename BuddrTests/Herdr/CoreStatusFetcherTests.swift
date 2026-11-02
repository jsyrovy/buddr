import Foundation
import Testing

@testable import Buddr

struct CoreStatusFetcherTests {
    private static let devbox = AgentSource.core(machine: "devbox")
    private static let pi = AgentSource.core(machine: "pi")

    private func fetcher(_ transport: FakeCoreTransport) -> CoreStatusFetcher {
        CoreStatusFetcher(transport: transport)
    }

    @Test func agentsAreTheTerminalsThatReportAStatus() async throws {
        let snapshot = await fetcher(try .fixture("core-terminal-list")).fetch()

        #expect(snapshot.sources == [.core(machine: nil), Self.devbox, Self.pi])
        // Shells report no status; pi is not connected.
        #expect(snapshot.agents.map(\.paneID) == ["t8", "t10", "t12", "devbox/t7"])
        #expect(
            snapshot.agents.map(\.source) == [
                .core(machine: nil), .core(machine: nil), .core(machine: nil), Self.devbox,
            ])
        // `error` (t12) counts as blocked.
        #expect(snapshot.agents.map(\.status) == [.done, .working, .blocked, .blocked])
        #expect(snapshot.agents.last?.workspace == "shop")
    }

    @Test func agentsTakeTheirWorkspaceFromHerdrAppsLabels() async throws {
        let snapshot = await fetcher(try .fixture("core-terminal-list")).fetch()
        let first = try #require(snapshot.agents.first)

        #expect(
            first
                == AgentRecord(
                    source: .core(machine: nil), workspaceID: "sp0d1a0972700155b544e415bdce74f671",
                    workspace: "buddr", workspaceNumber: nil, paneID: "t8", agent: "claude-code", status: .done,
                    title: "Fix the parser", cwd: "/Users/me/code/buddr", statusOrder: 1_793_610_990_497))
        // Both tabs of the workspace are one group.
        #expect(snapshot.agents[1].workspaceID == first.workspaceID)
        #expect(snapshot.agents[1].workspace == "buddr")
    }

    @Test func terminalWithoutLabelsIsGroupedByItsDirectory() async throws {
        let snapshot = await fetcher(try .fixture("core-terminal-list")).fetch()
        let review = try #require(snapshot.agents.first { $0.paneID == "t12" })

        #expect(review.workspace == "api")
        #expect(review.workspaceID == "api")
        #expect(review.title == "")
        #expect(review.displayTitle == "api")
    }

    @Test func coreThatIsNotRunningIsAFailureOfThisMac() async {
        let transport = FakeCoreTransport(.failure(.notRunning(socketPath: "/s.sock")))
        let snapshot = await fetcher(transport).fetch()

        #expect(
            snapshot
                == HerdrSnapshot(
                    agents: [],
                    failures: [
                        SourceFailure(
                            source: .core(machine: nil), message: "hc is not running (nothing listens on /s.sock)")
                    ],
                    sources: [.core(machine: nil)]))
    }

    @Test func machineThatIsNotConnectedIsAFailureWithoutAgents() async throws {
        let snapshot = await fetcher(try .fixture("core-terminal-list")).fetch()

        #expect(
            snapshot.failures == [
                SourceFailure(
                    source: Self.pi, message: "unreachable: ssh: connect to host pi port 22: Operation timed out")
            ])
        #expect(!snapshot.agents.contains { $0.source == Self.pi })
    }

    @Test func machineStateWithoutAReasonIsTheMessage() async throws {
        let answer = #"""
            {"id":1,"jsonrpc":"2.0","result":{"hidden_finished":0,"terminals":[],"machines":[
            {"host":"pi","id":"2b4d","name":"pi","state":"needs_login","target":"pi","version":"0.1.16"}]}}
            """#
        let snapshot = await fetcher(FakeCoreTransport(.success(Data(answer.utf8)))).fetch()

        #expect(snapshot.failures == [SourceFailure(source: Self.pi, message: "needs login")])
    }

    @Test func onlyThisMacWhenNoMachineWasAdded() async throws {
        let snapshot = await fetcher(try .fixture("core-terminal-list-empty")).fetch()

        #expect(snapshot == HerdrSnapshot(agents: [], failures: [], sources: [.core(machine: nil)]))
    }

    @Test func machineIsThePartOfTheAddressBeforeTheSlash() {
        #expect(CoreStatusFetcher.machine(of: "t7") == nil)
        #expect(CoreStatusFetcher.machine(of: "rohan/t7") == "rohan")
    }

    @Test func statusWordsOfTheCore() {
        #expect(AgentStatus(coreState: "idle") == .idle)
        #expect(AgentStatus(coreState: "working") == .working)
        #expect(AgentStatus(coreState: "done") == .done)
        #expect(AgentStatus(coreState: "blocked") == .blocked)
        #expect(AgentStatus(coreState: "error") == .blocked)
        #expect(AgentStatus(coreState: "dreaming") == .unknown)
    }
}
