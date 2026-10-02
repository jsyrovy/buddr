import Foundation
import Observation

/// User preferences shown in the menu bar, saved in `UserDefaults`.
@MainActor
@Observable
final class Preferences {
    private static let watchesRemoteMachinesKey = "watchesRemoteMachines"

    /// Whether agents on saved herdr machines count, besides local sessions. On by default.
    var watchesRemoteMachines: Bool {
        didSet {
            defaults.set(watchesRemoteMachines, forKey: Self.watchesRemoteMachinesKey)
            onChange?()
        }
    }

    /// Called after a preference changed.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        watchesRemoteMachines = defaults.object(forKey: Self.watchesRemoteMachinesKey) as? Bool ?? true
    }
}
