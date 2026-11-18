import Foundation
import os

/// Collects `AgentSnapshot`s of Rex: the server on this Mac, or the servers of Rex.app's SSH hosts.
///
/// Every server is read over one connection in four rounds of requests, each round sent at once:
/// `session.attach_all` (the sessions), `session.list_blocks` of every session, `program_status` of every terminal,
/// and `title` and `pwd` of the terminals with a status – the agents. Sessions and blocks gone in between are skipped.
/// Never throws: every problem ends up in `AgentSnapshot.failures`.
struct RexStatusFetcher: Sendable {
    /// The server on this Mac answers at once; a host's goes over SSH.
    static let localTimeout: Duration = .seconds(5)
    static let machineTimeout: Duration = .seconds(10)
    static let terminalCreator = "com.superlogical.terminal"

    var locator = RexLocator()
    var connector: @Sendable (_ socketPath: String) -> any RexConnector = { RexSocketConnector(path: $0) }
    var findTunnels: @Sendable (_ directory: String) -> [RexTunnel] = { RexTunnels.find(in: $0) }
    /// The labels of the hosts by endpoint, and the endpoints of the tunnels they were asked for.
    let hostLabels = OSAllocatedUnfairLock<(endpoints: Set<String>, labels: [String: String])?>(
        initialState: nil)

    /// The server on this Mac; one that is not running is a failure.
    @concurrent
    func fetchLocal() async -> AgentSnapshot {
        Self.snapshot(of: .rex(machine: nil), from: connector(locator.socketPath), timeout: Self.localTimeout)
    }

    /// The servers of Rex.app's hosts that it has a tunnel to, by label (a host without one by its host name); no
    /// sources while Rex.app has none. Every host is a source, a failed one too.
    @concurrent
    func fetchMachines() async -> AgentSnapshot {
        let tunnels = findTunnels(locator.tunnelDirectory)
        guard !tunnels.isEmpty else { return .empty }
        let labels = labels(for: tunnels)
        let parts = await withTaskGroup(of: (Int, AgentSnapshot).self) { group in
            for (index, tunnel) in tunnels.enumerated() {
                let source = AgentSource.rex(machine: labels[tunnel.endpoint] ?? tunnel.hostName)
                group.addTask { [connector] in
                    (index, Self.snapshot(of: source, from: connector(tunnel.socketPath), timeout: Self.machineTimeout))
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        return AgentSnapshot.combining(parts.sorted { $0.0 < $1.0 }.map(\.1))
    }

    /// The label of every host by endpoint, from the server on this Mac. Asked again only when the tunnels change, so
    /// polling the hosts doesn't connect to this Mac's server too; none (and asked again next time) if it can't be
    /// asked.
    private func labels(for tunnels: [RexTunnel]) -> [String: String] {
        let endpoints = Set(tunnels.map(\.endpoint))
        if let known = hostLabels.withLock({ $0 }), known.endpoints == endpoints {
            return known.labels
        }
        let deadline = ContinuousClock.now + Self.localTimeout
        guard let connection = try? connector(locator.socketPath).connect(until: deadline) else { return [:] }
        defer { connection.close() }
        guard let hosts = try? RexClient.call([.hosts], on: connection, until: deadline, as: RexHostList.self)[0].get()
        else { return [:] }
        var labels: [String: String] = [:]
        for host in hosts.hosts ?? [] {
            for endpoint in host.endpoints ?? [] where labels[endpoint] == nil {
                labels[endpoint] = host.label
            }
        }
        hostLabels.withLock { [labels] in $0 = (endpoints, labels) }
        return labels
    }

    /// One server as `source`.
    static func snapshot(
        of source: AgentSource, from connector: any RexConnector, timeout: Duration
    ) -> AgentSnapshot {
        do {
            let deadline = ContinuousClock.now + timeout
            let connection = try connector.connect(until: deadline)
            defer { connection.close() }
            let agents = try agents(of: source, on: connection, until: deadline)
            return AgentSnapshot(agents: agents, failures: [], sources: [source])
        } catch {
            return AgentSnapshot(agents: [], failures: [SourceFailure(source: source, error: error)], sources: [source])
        }
    }

    /// A terminal block, with the position of its session.
    private struct Terminal {
        let session: Int
        let block: String
    }

    private static func agents(
        of source: AgentSource, on connection: any RexConnection, until deadline: ContinuousClock.Instant
    ) throws -> [AgentRecord] {
        let sessions =
            try RexClient.call([.attachAll], on: connection, until: deadline, as: RexSessionList.self)[0].get()
            .sessions ?? []
        let blockLists = try RexClient.call(
            sessions.map { .blocks(of: $0.sessionId) }, on: connection, until: deadline, as: RexBlockList.self)
        // Terminals in the order of their sessions, then of their IDs.
        var terminals: [Terminal] = []
        for (index, list) in blockLists.enumerated() {
            for block in try skippingGone(list)?.blocks ?? [] where block.creatorName == terminalCreator {
                if let id = block.blockId {
                    terminals.append(Terminal(session: index, block: id))
                }
            }
        }
        func requests(_ method: String, for terminals: [Terminal]) -> [RexRequest] {
            terminals.map { .blockMethod(method, session: sessions[$0.session].sessionId, block: $0.block) }
        }
        let statuses = try RexClient.call(
            requests("program_status", for: terminals), on: connection, until: deadline, as: RexProgramStatus.self)
        var agents: [(terminal: Terminal, record: RexProgramStatus.Record, status: AgentStatus)] = []
        for (terminal, status) in zip(terminals, statuses) {
            if let records = try skippingGone(status)?.records, let (record, status) = mostUrgent(records) {
                agents.append((terminal, record, status))
            }
        }
        // The titles, then the directories, in one round. Without them an agent is still shown, by its block ID.
        let details = try connection.call(
            requests("title", for: agents.map(\.terminal)) + requests("pwd", for: agents.map(\.terminal)),
            until: deadline)
        return agents.enumerated().map { index, agent in
            let title = try? RexClient.payload(RexTitle.self, of: details[index], method: "block.method")
            let directory = try? RexClient.payload(
                RexDirectory.self, of: details[agents.count + index], method: "block.method")
            return AgentRecord(
                rexRecord: agent.record, status: agent.status, source: source,
                session: sessions[agent.terminal.session], sessionNumber: agent.terminal.session,
                block: agent.terminal.block, title: title?.title ?? "", directory: directory?.pwd)
        }
    }

    /// The record a terminal's status comes from: the most urgent one, the first of them on a tie (the root before
    /// its children); `nil` without records.
    static func mostUrgent(_ records: [RexProgramStatus.Record]) -> (RexProgramStatus.Record, AgentStatus)? {
        let statuses = records.map { AgentStatus(rexState: $0.state) }
        // `max(by:)` keeps the first of equal elements.
        return statuses.indices.max { statuses[$0] < statuses[$1] }.map { (records[$0], statuses[$0]) }
    }

    /// The payload, or `nil` when the request named something that is gone by now.
    private static func skippingGone<Payload>(_ result: Result<Payload, RexError>) throws -> Payload? {
        do {
            return try result.get()
        } catch  where error.isNotFound {
            return nil
        }
    }
}

extension AgentRecord {
    /// The agent in a Rex terminal whose status comes from `record`. The session is the workspace, in the server's
    /// order.
    init(
        rexRecord record: RexProgramStatus.Record, status: AgentStatus, source: AgentSource, session: RexSession,
        sessionNumber: Int, block: String, title: String, directory: String?
    ) {
        self.init(
            source: source, workspaceID: session.sessionId,
            workspace: session.label.isEmpty ? session.sessionId : session.label,
            workspaceNumber: sessionNumber, paneID: block, agent: record.effectiveApp ?? record.app,
            status: status, title: title, cwd: directory.map(Self.path(ofDirectory:)),
            statusOrder: record.updatedAt.flatMap(Self.milliseconds(sinceEpoch:)))
    }

    /// The path of a directory a terminal reported: a `file://` URL (OSC 7) or a plain path.
    static func path(ofDirectory directory: String) -> String {
        guard directory.hasPrefix("file://"), let url = URL(string: directory) else { return directory }
        return url.path(percentEncoded: false)
    }

    /// An RFC 3339 time, with any number of fractional digits (Rex sends nanoseconds), in ms since the epoch.
    static func milliseconds(sinceEpoch time: String) -> UInt64? {
        guard let date = try? Date.ISO8601FormatStyle().parse(time) else { return nil }
        return UInt64(max(0, (date.timeIntervalSince1970 * 1000).rounded()))
    }
}

extension AgentStatus {
    /// A Rex status word (OSC 7501). `error` (the program stopped on an error) counts as `blocked`, as in herdr-core;
    /// words added later as `idle`, as Rex asks.
    init(rexState: String) {
        switch rexState {
        case "working": self = .working
        case "blocked", "error": self = .blocked
        case "done": self = .done
        default: self = .idle
        }
    }
}
