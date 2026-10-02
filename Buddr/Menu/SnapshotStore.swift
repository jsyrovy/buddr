import Observation

/// The latest combined herdr snapshot, observed by the menu bar list.
@MainActor
@Observable
final class SnapshotStore {
    /// `nil` until the first poll has finished.
    var snapshot: HerdrSnapshot?
}
