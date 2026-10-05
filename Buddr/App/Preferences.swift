import Foundation
import Observation

/// User preferences shown in the menu bar, saved in `UserDefaults`.
@MainActor
@Observable
final class Preferences {
    // Keys, choices and defaults are mirrored in `Settings.read()` of scripts/measure.swift.
    private static let watchesRemoteMachinesKey = "watchesRemoteMachines"
    private static let animationModeKey = "animationMode"
    private static let animationSecondsKey = "animationDurationSeconds"
    private static let hideModeKey = "hideMode"
    private static let hideMinutesKey = "hideAfterMinutes"

    /// The choices for `animationSeconds`.
    static let animationSecondsChoices = [5, 10, 30, 60]
    static let defaultAnimationSeconds = 10
    /// The choices for `hideMinutes`.
    static let hideMinutesChoices = [1, 5, 15, 30]
    static let defaultHideMinutes = 5

    /// Whether agents on saved herdr machines count, besides local sessions. On by default.
    var watchesRemoteMachines: Bool {
        didSet {
            defaults.set(watchesRemoteMachines, forKey: Self.watchesRemoteMachinesKey)
            onChange?()
        }
    }

    /// When the sheep moves. Always by default.
    var animationMode: AnimationMode {
        didSet {
            defaults.set(animationMode.rawValue, forKey: Self.animationModeKey)
            onChange?()
        }
    }

    /// How long the sheep moves after a change in the `onChange` mode, one of `animationSecondsChoices`.
    var animationSeconds: Int {
        didSet {
            defaults.set(animationSeconds, forKey: Self.animationSecondsKey)
            onChange?()
        }
    }

    /// When the sheep hides on its own. Never by default.
    var hideMode: HideMode {
        didSet {
            defaults.set(hideMode.rawValue, forKey: Self.hideModeKey)
            onChange?()
        }
    }

    /// How long the sheep waits before it hides, one of `hideMinutesChoices`.
    var hideMinutes: Int {
        didSet {
            defaults.set(hideMinutes, forKey: Self.hideMinutesKey)
            onChange?()
        }
    }

    /// Called after a preference changed.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        watchesRemoteMachines = defaults.object(forKey: Self.watchesRemoteMachinesKey) as? Bool ?? true
        animationMode =
            defaults.string(forKey: Self.animationModeKey).flatMap { AnimationMode(rawValue: $0) } ?? .always
        // A value that isn't offered in the menu (none saved, or edited by hand) falls back to the default.
        let seconds = defaults.integer(forKey: Self.animationSecondsKey)
        animationSeconds = Self.animationSecondsChoices.contains(seconds) ? seconds : Self.defaultAnimationSeconds
        hideMode = defaults.string(forKey: Self.hideModeKey).flatMap { HideMode(rawValue: $0) } ?? .never
        let minutes = defaults.integer(forKey: Self.hideMinutesKey)
        hideMinutes = Self.hideMinutesChoices.contains(minutes) ? minutes : Self.defaultHideMinutes
    }
}
