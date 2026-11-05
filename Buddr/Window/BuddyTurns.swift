import os

/// Which buddy sits on the screen: one chosen in the menu bar, or every buddy taking turns.
enum BuddyChoice: Hashable, Sendable {
    case one(BuddyID)
    case takingTurns

    private static let takingTurnsValue = "takeTurns"

    /// The buddy's ID, or `takeTurns`.
    var rawValue: String {
        switch self {
        case .one(let id): id.rawValue
        case .takingTurns: Self.takingTurnsValue
        }
    }

    init?(rawValue: String) {
        if rawValue == Self.takingTurnsValue {
            self = .takingTurns
        } else if let id = BuddyID(rawValue: rawValue) {
            self = .one(id)
        } else {
            return nil
        }
    }
}

extension BuddyID {
    /// The buddy after this one in the order of the menu; the first one after the last.
    var next: BuddyID {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Decides which buddy is on the screen: the chosen one, or – taking turns – the next one (`BuddyID.next`) after every
/// `interval`.
///
/// A turn ends only while no agent needs the user (`AgentStatus.needsAttention`): an agent that gets `blocked` or
/// `done` is never covered by buddies changing places. A turn that is over by then waits until it is calm, and the
/// next one starts with the change. Moving the buddies is up to `onChange`.
@MainActor
final class BuddyTurns {
    private static let logger = Logger(subsystem: "cz.jsyrovy.buddr", category: "buddies")

    private(set) var current: BuddyID
    /// Whether the turn is over and the change waits for calm.
    private(set) var isTurnOver = false

    /// Called when `current` changed.
    var onChange: (@MainActor (BuddyID) -> Void)?

    private var choice: BuddyChoice?
    private var interval = Duration.zero
    private var status = AgentStatus.unknown
    private let countdown: Countdown

    /// Starts with `current` on the screen. `sleep` is replaced in tests to end a turn on demand.
    init(
        current: BuddyID,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.current = current
        countdown = Countdown(sleep: sleep)
    }

    /// Shows the chosen buddy at once, or starts taking turns with a new turn of the current one.
    func setChoice(_ choice: BuddyChoice, every interval: Duration) {
        guard choice != self.choice || interval != self.interval else { return }
        self.choice = choice
        self.interval = interval
        isTurnOver = false
        switch choice {
        case .one(let id):
            countdown.cancel()
            setCurrent(id)
        case .takingTurns:
            startTurn()
        }
    }

    func setStatus(_ status: AgentStatus) {
        self.status = status
        if isTurnOver {
            endTurn()
        }
    }

    private func startTurn() {
        countdown.start(after: interval) { [weak self] in
            self?.endTurn()
        }
    }

    private func endTurn() {
        guard !status.needsAttention else {
            isTurnOver = true
            return
        }
        isTurnOver = false
        setCurrent(current.next)
        startTurn()
    }

    private func setCurrent(_ id: BuddyID) {
        guard id != current else { return }
        current = id
        Self.logger.info("Showing the buddy \(id.rawValue, privacy: .public)")
        onChange?(id)
    }
}
