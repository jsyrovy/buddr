import os

/// Watches all kinds of sources (herdr and herdr-core) and reports their combined snapshot on the main actor when it
/// changes.
///
/// Every kind of source has its own `HerdrPoller` and interval, so a slow or unreachable machine never delays the
/// local sessions, and one backend never delays the other. A kind contributes nothing until its first poll has
/// finished, and nothing while it is disabled. Remote sources can be left out of the combined snapshot
/// (`configure(backends:watchesRemoteMachines:)`).
@MainActor
final class HerdrMonitor {
    /// The kinds of sources.
    enum SourceKind: CaseIterable, Sendable {
        /// herdr's local sessions.
        case localSessions
        /// herdr's saved machines.
        case machines
        /// herdr-core with its machines.
        case core

        /// Whether the kind runs with these menu bar settings. herdr's machines are polled only while remote machines
        /// are watched, because every poll runs `herdr --machine`; herdr-core answers for its machines in the same
        /// call, so they are just left out of the snapshot.
        func isEnabled(by backends: Set<Backend>, watchesRemoteMachines: Bool) -> Bool {
            switch self {
            case .localSessions: backends.contains(.herdr)
            case .machines: backends.contains(.herdr) && watchesRemoteMachines
            case .core: backends.contains(.hc)
            }
        }
    }

    /// herdr's local sessions every 2 s, its saved machines every 15 s (every poll runs `herdr` per machine).
    /// herdr-core every 2 s: one call needs no subprocess and doesn't wait for machines that are not connected.
    static var defaultFeeds: [SourceKind: HerdrPoller.Feed] {
        let herdr = HerdrStatusFetcher()
        let core = CoreStatusFetcher()
        return [
            .localSessions: .init(interval: .seconds(2), fetch: { await herdr.fetchSessions() }),
            .machines: .init(interval: .seconds(15), fetch: { await herdr.fetchMachines() }),
            .core: .init(interval: .seconds(2), fetch: { await core.fetch() }),
        ]
    }

    private static let logger = Logger(subsystem: "cz.jsyrovy.buddr", category: "herdr")

    private let onUpdate: @MainActor (HerdrSnapshot) -> Void
    // Assigned once; a `var` because the pollers' callbacks capture `self`.
    private var pollers: [SourceKind: HerdrPoller] = [:]
    /// The latest snapshot of every enabled kind that has finished a poll.
    private var parts: [SourceKind: HerdrSnapshot] = [:]
    private var disabled: Set<SourceKind> = []
    private var watchesRemoteMachines = true
    private var isRunning = false
    private var lastSnapshot: HerdrSnapshot?

    init(
        feeds: [SourceKind: HerdrPoller.Feed] = HerdrMonitor.defaultFeeds,
        onUpdate: @escaping @MainActor (HerdrSnapshot) -> Void
    ) {
        self.onUpdate = onUpdate
        for (kind, feed) in feeds {
            pollers[kind] = HerdrPoller(feed) { [weak self] snapshot in
                self?.update(kind, with: snapshot)
            }
        }
    }

    /// Starts polling the enabled kinds of sources.
    func start() {
        isRunning = true
        for kind in SourceKind.allCases where !disabled.contains(kind) {
            pollers[kind]?.start()
        }
    }

    /// Stops all feeds and waits for their loops to end.
    func stop() async {
        isRunning = false
        await withDiscardingTaskGroup { group in
            for poller in pollers.values {
                group.addTask { await poller.stop() }
            }
        }
    }

    /// Polls every enabled kind right away, unless its poll is already running (disabled kinds don't run). For a
    /// fresh view when the agent list opens.
    func refresh() {
        Self.logger.info("refresh")
        for poller in pollers.values {
            poller.refresh()
        }
    }

    /// Applies the menu bar settings: enables the kinds they ask for (`setEnabled(_:_:)`) and, without remote
    /// machines, leaves every remote source out of the snapshot at once.
    func configure(backends: Set<Backend>, watchesRemoteMachines: Bool) {
        for kind in SourceKind.allCases {
            setEnabled(kind.isEnabled(by: backends, watchesRemoteMachines: watchesRemoteMachines), kind)
        }
        guard watchesRemoteMachines != self.watchesRemoteMachines else { return }
        self.watchesRemoteMachines = watchesRemoteMachines
        publish()
    }

    /// All kinds are enabled initially; disabling one before `start()` keeps it from being polled. Enabling a kind
    /// polls it right away (if the monitor runs). Disabling it stops its polling and removes its
    /// agents and failures from the snapshot at once.
    func setEnabled(_ enabled: Bool, _ kind: SourceKind) {
        guard enabled == disabled.contains(kind) else { return }
        Self.logger.info("\(String(describing: kind), privacy: .public) \(enabled ? "on" : "off", privacy: .public)")
        if enabled {
            disabled.remove(kind)
            if isRunning {
                pollers[kind]?.start()
            }
        } else {
            disabled.insert(kind)
            pollers[kind]?.cancel()
            if parts.removeValue(forKey: kind) != nil {
                publish()
            }
        }
    }

    private func update(_ kind: SourceKind, with snapshot: HerdrSnapshot) {
        guard parts[kind] != snapshot else { return }
        parts[kind] = snapshot
        publish()
    }

    private func publish() {
        var combined = HerdrSnapshot.combining(SourceKind.allCases.compactMap { parts[$0] })
        if !watchesRemoteMachines {
            combined = combined.withoutRemoteSources()
        }
        guard combined != lastSnapshot else { return }
        log(combined)
        lastSnapshot = combined
        onUpdate(combined)
    }

    /// Logs the status, and the failures when they changed.
    private func log(_ snapshot: HerdrSnapshot) {
        if snapshot.failures != lastSnapshot?.failures ?? [] {
            if snapshot.failures.isEmpty {
                Self.logger.info("all sources reachable")
            }
            for failure in snapshot.failures {
                Self.logger.error(
                    "\(failure.source?.displayName ?? "herdr", privacy: .public): \(failure.message, privacy: .public)")
            }
        }
        Self.logger.info("status \(snapshot.status.rawValue, privacy: .public), \(snapshot.agents.count) agent(s)")
    }
}
