import Foundation
import Testing

@testable import Buddr

struct RexStatusFetcherTests {
    private static let home = "/Users/me"
    private static let localSocket = "/Users/me/Library/Application Support/rex/server.sock"
    private static let tunnelDirectory = "/Users/me/Library/Application Support/rex/ssh"

    private static func status(_ session: String, _ block: String) -> RexRequest {
        .blockMethod("program_status", session: session, block: block)
    }

    /// A server with two sessions and a third that is destroyed while it is read; in them a terminal with a nested
    /// status, a shell without one, a tunnel (not a terminal), a terminal closed while it is read, and a program that
    /// stopped on an error. Shapes as Rex 0.1.0-preview.19 answers.
    private static let server: [RexRequest: FakeRexConnector.Answer] = [
        .attachAll: .payload(
            #"{"sessions":[{"session_id":"s1","label":"buddr"},{"session_id":"s2","label":""},"#
                + #"{"session_id":"s3","label":"gone"}]}"#),
        .blocks(of: "s1"): .payload(
            #"{"blocks":[{"block_id":"b1","label":"shell","creator_name":"com.superlogical.terminal","#
                + #""flavor":"com.superlogical.terminal.shell","placement":"placed","window_id":"w1"},"#
                + #"{"block_id":"b2","label":"shell","creator_name":"com.superlogical.terminal","placement":"placed"},"#
                + #"{"block_id":"b3","label":"tunnel","creator_name":"com.superlogical.tunnel","placement":"detached"},"#
                + #"{"block_id":"b4","label":"shell","creator_name":"com.superlogical.terminal","placement":"placed"}]}"#
        ),
        .blocks(of: "s2"): .payload(
            #"{"blocks":[{"block_id":"b5","label":"shell","creator_name":"com.superlogical.terminal","placement":"placed"}]}"#
        ),
        .blocks(of: "s3"): .error("session_not_found"),
        status("s1", "b1"): .payload(
            #"{"records":[{"state":"working","app":"claude-code","effective_app":"claude-code","#
                + #""updated_at":"2026-11-19T13:29:34.408037863+01:00","owner":{"pid":91272,"name":"2.1.327"}},"#
                + #"{"id":"tool","state":"blocked","kind":"permission","effective_app":"claude-code","#
                + #""updated_at":"2026-11-19T12:30:00Z"}]}"#),
        status("s1", "b2"): .payload(#"{"records":[]}"#),
        status("s1", "b4"): .error("not_found"),
        status("s2", "b5"): .payload(
            #"{"records":[{"state":"error","app":"codex","updated_at":"2026-11-19T12:00:00+00:00"}]}"#),
        .blockMethod("title", session: "s1", block: "b1"): .payload(#"{"title":"Claude Code"}"#),
        .blockMethod("pwd", session: "s1", block: "b1"): .payload(
            #"{"pwd":"file://studio.example/Users/me/code/buddr%20app","owner":{"pid":1,"name":"zsh"}}"#),
        .blockMethod("title", session: "s2", block: "b5"): .error("not_found"),
        .blockMethod("pwd", session: "s2", block: "b5"): .payload(#"{}"#),
    ]

    private func fetcher(_ connectors: [String: FakeRexConnector], tunnels: [RexTunnel] = []) -> RexStatusFetcher {
        RexStatusFetcher(
            locator: RexLocator(environment: [:], homeDirectory: Self.home),
            connector: { connectors[$0] ?? FakeRexConnector(failing: .notRunning(socketPath: $0)) },
            findTunnels: { $0 == Self.tunnelDirectory ? tunnels : [] })
    }

    @Test func agentsAreTheTerminalsWithAStatus() async throws {
        let connector = FakeRexConnector(Self.server)
        let snapshot = await fetcher([Self.localSocket: connector]).fetchLocal()

        #expect(snapshot.sources == [.rex(machine: nil)])
        #expect(snapshot.failures.isEmpty)
        #expect(
            snapshot.agents == [
                AgentRecord(
                    source: .rex(machine: nil), workspaceID: "s1", workspace: "buddr", workspaceNumber: 0,
                    paneID: "b1", agent: "claude-code", status: .blocked, title: "Claude Code",
                    cwd: "/Users/me/code/buddr app", statusOrder: 1_795_091_400_000),
                // An empty session label shows the session's ID; `error` counts as blocked.
                AgentRecord(
                    source: .rex(machine: nil), workspaceID: "s2", workspace: "s2", workspaceNumber: 1, paneID: "b5",
                    agent: "codex", status: .blocked, title: "", cwd: nil, statusOrder: 1_795_089_600_000),
            ])
        #expect(
            connector.rounds == [
                [.attachAll],
                [.blocks(of: "s1"), .blocks(of: "s2"), .blocks(of: "s3")],
                [Self.status("s1", "b1"), Self.status("s1", "b2"), Self.status("s1", "b4"), Self.status("s2", "b5")],
                [
                    .blockMethod("title", session: "s1", block: "b1"),
                    .blockMethod("title", session: "s2", block: "b5"),
                    .blockMethod("pwd", session: "s1", block: "b1"), .blockMethod("pwd", session: "s2", block: "b5"),
                ],
            ])
        #expect(connector.openConnections == 0)
    }

    @Test func serverWithoutSessionsHasNoAgents() async {
        let connector = FakeRexConnector([.attachAll: .payload(#"{"sessions":null}"#)])
        let snapshot = await fetcher([Self.localSocket: connector]).fetchLocal()

        #expect(snapshot == AgentSnapshot(agents: [], failures: [], sources: [.rex(machine: nil)]))
        #expect(connector.rounds == [[.attachAll]])
    }

    @Test func serverThatIsNotRunningIsAFailure() async {
        let snapshot = await fetcher([:]).fetchLocal()

        #expect(snapshot.sources == [.rex(machine: nil)])
        #expect(snapshot.agents.isEmpty)
        #expect(
            snapshot.failures == [
                SourceFailure(
                    source: .rex(machine: nil), message: "rex is not running (nothing listens on \(Self.localSocket))")
            ])
    }

    @Test func errorThatIsNotAboutSomethingGoneFailsTheServer() async {
        var answers = Self.server
        answers[.blocks(of: "s2")] = .error("conflict")
        let connector = FakeRexConnector(answers)
        let snapshot = await fetcher([Self.localSocket: connector]).fetchLocal()

        #expect(snapshot.agents.isEmpty)
        #expect(
            snapshot.failures == [
                SourceFailure(source: .rex(machine: nil), message: "session.list_blocks: conflict message (conflict)")
            ])
        #expect(connector.openConnections == 0)
    }

    @Test func machinesAreTheHostsRexAppHasTunnelsTo() async throws {
        let studio = RexTunnel(socketPath: "\(Self.tunnelDirectory)/1.sock", endpoint: "ssh://studio")
        let pi = RexTunnel(socketPath: "\(Self.tunnelDirectory)/2.sock", endpoint: "ssh://me@pi.local:2222")
        let local = FakeRexConnector([
            .hosts: .payload(
                #"{"hosts":[{"id":"host:1","label":"Studio","endpoints":["studio.ts.net","ssh://studio"]}],"hash":"x"}"#
            )
        ])
        let remote = FakeRexConnector(Self.server)
        let snapshot = await fetcher(
            [Self.localSocket: local, studio.socketPath: remote], tunnels: [studio, pi]
        ).fetchMachines()

        // The label comes from the hosts of this Mac's server; a host that isn't there is named by its host name.
        #expect(snapshot.sources == [.rex(machine: "Studio"), .rex(machine: "pi.local")])
        #expect(snapshot.agents.map(\.paneID) == ["b1", "b5"])
        #expect(snapshot.agents.allSatisfy { $0.source == .rex(machine: "Studio") })
        #expect(
            snapshot.failures == [
                SourceFailure(
                    source: .rex(machine: "pi.local"),
                    message: "rex is not running (nothing listens on \(pi.socketPath))"
                )
            ])
        #expect(local.rounds == [[.hosts]])
        #expect(local.openConnections == 0)
    }

    @Test func hostsAreNamedByTheirHostNameWithoutTheServerOfThisMac() async {
        let tunnel = RexTunnel(socketPath: "\(Self.tunnelDirectory)/1.sock", endpoint: "ssh://studio")
        let snapshot = await fetcher(
            [tunnel.socketPath: FakeRexConnector([.attachAll: .payload(#"{"sessions":[]}"#)])], tunnels: [tunnel]
        ).fetchMachines()

        #expect(snapshot == AgentSnapshot(agents: [], failures: [], sources: [.rex(machine: "studio")]))
    }

    @Test func withoutTunnelsThereAreNoMachines() async {
        let local = FakeRexConnector(Self.server)
        let snapshot = await fetcher([Self.localSocket: local]).fetchMachines()

        #expect(snapshot == .empty)
        #expect(local.rounds.isEmpty)
    }

    @Test func statusWords() {
        #expect(
            ["idle", "working", "done", "blocked", "error", "thinking"].map(AgentStatus.init(rexState:)) == [
                .idle, .working, .done, .blocked, .blocked, .idle,
            ])
    }

    @Test func mostUrgentRecordWinsAndTheFirstOnATie() throws {
        let session = RexSession(sessionId: "s", label: "web")
        func record(_ id: String?, _ state: String, app: String?) -> RexProgramStatus.Record {
            RexProgramStatus.Record(id: id, state: state, app: app, effectiveApp: nil, updatedAt: nil)
        }
        let agent = try #require(
            AgentRecord(
                rexRecords: [
                    record(nil, "done", app: "root"), record("a", "done", app: "child"), record("b", "idle", app: nil),
                ],
                source: .rex(machine: nil), session: session, sessionNumber: 3, block: "b", title: "", directory: nil))

        #expect(agent.status == .done)
        #expect(agent.agent == "root")
        #expect(agent.statusOrder == nil)
        #expect(agent.workspaceNumber == 3)
        #expect(
            AgentRecord(
                rexRecords: [], source: .rex(machine: nil), session: session, sessionNumber: 0, block: "b", title: "",
                directory: nil) == nil)
    }

    @Test func timesWithAnyFraction() {
        #expect(AgentRecord.milliseconds(sinceEpoch: "2026-11-19T13:29:34.408037863+01:00") == 1_795_091_374_408)
        #expect(AgentRecord.milliseconds(sinceEpoch: "2026-11-19T12:29:34.4Z") == 1_795_091_374_400)
        #expect(AgentRecord.milliseconds(sinceEpoch: "2026-11-19T12:29:34Z") == 1_795_091_374_000)
        #expect(AgentRecord.milliseconds(sinceEpoch: "yesterday") == nil)
    }

    @Test func directoriesAreURLsOrPaths() {
        #expect(AgentRecord.path(ofDirectory: "file://host/home/me/a%20b") == "/home/me/a b")
        #expect(AgentRecord.path(ofDirectory: "/home/me") == "/home/me")
    }
}

struct RexClientTests {
    @Test func requestMessages() {
        #expect(RexRequest.hosts.message(id: "7") == #"{"type":"request","id":"7","method":"hosts.list"}"#)
        #expect(
            RexRequest.blockMethod("title", session: #"s"1"#, block: "b").message(id: "1")
                == #"{"type":"request","id":"1","method":"block.method","payload":"#
                + #"{"session_id":"s\"1","block_id":"b","method":"title","args":{}}}"#)
    }

    @Test func payloadOrError() throws {
        let ok = Data(#"{"type":"response","id":"1","seq":0,"payload":{"title":"x"}}"#.utf8)
        #expect(try RexClient.payload(RexTitle.self, of: ok, method: "m").title == "x")

        let error = Data(
            #"{"type":"response","id":"1","seq":0,"error":{"code":"not_found","message":"block not found","status":404}}"#
                .utf8)
        #expect(throws: RexError.api(method: "m", code: "not_found", message: "block not found")) {
            try RexClient.payload(RexTitle.self, of: error, method: "m")
        }
        #expect(RexError.api(method: "m", code: "not_found", message: "").isNotFound)
        #expect(RexError.api(method: "m", code: "session_not_found", message: "").isNotFound)
        #expect(!RexError.api(method: "m", code: "conflict", message: "").isNotFound)
        #expect(!RexError.timedOut.isNotFound)

        #expect(throws: RexError.invalidOutput(method: "m", reason: "neither payload nor error")) {
            try RexClient.payload(RexTitle.self, of: Data(#"{"type":"response","id":"1"}"#.utf8), method: "m")
        }
        #expect {
            try RexClient.payload(RexTitle.self, of: Data("not json".utf8), method: "m")
        } throws: { error in
            if case .invalidOutput(method: "m", _) = error as? RexError { true } else { false }
        }
    }

    @Test func errorDescriptions() {
        #expect(RexError.timedOut.description == "rex did not answer in time")
        #expect(RexError.connectionFailed(reason: "x").description == "rex: x")
        #expect(RexError.api(method: "m", code: "c", message: "text").description == "m: text (c)")
        #expect(RexError.invalidOutput(method: "m", reason: "r").description == "m: unexpected output: r")
    }

    @Test func socketOfThisMac() {
        let locator = RexLocator(environment: [:], homeDirectory: "/Users/me")
        #expect(locator.socketPath == "/Users/me/Library/Application Support/rex/server.sock")
        #expect(locator.tunnelDirectory == "/Users/me/Library/Application Support/rex/ssh")

        // Rex's terminals name their server; other addresses than a Unix socket are not followed.
        let inTerminal = RexLocator(
            environment: ["REX_SERVER": "unix:///Users/me/Library/Application%20Support/rex/server.sock"],
            homeDirectory: "/nowhere")
        #expect(inTerminal.socketPath == "/Users/me/Library/Application Support/rex/server.sock")
        let remote = RexLocator(environment: ["REX_SERVER": "studio.ts.net:443"], homeDirectory: "/Users/me")
        #expect(remote.socketPath == "/Users/me/Library/Application Support/rex/server.sock")
    }
}
