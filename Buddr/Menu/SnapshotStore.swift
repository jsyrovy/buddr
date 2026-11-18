import Observation

/// The latest combined snapshot of all backends, observed by the menu bar list.
@MainActor
@Observable
final class SnapshotStore {
    /// `nil` until the first poll has finished.
    var snapshot: AgentSnapshot?
}
