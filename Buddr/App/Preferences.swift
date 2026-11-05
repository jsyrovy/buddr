import Foundation
import Observation

/// User preferences shown in the menu bar, saved in `UserDefaults`.
@MainActor
@Observable
final class Preferences {
    // Keys, choices and defaults of the settings that change the cost (all but the name plate) are mirrored in
    // `Settings.read()` of scripts/measure.swift.
    private static let backendChoiceKey = "agentBackends"
    private static let watchesRemoteMachinesKey = "watchesRemoteMachines"
    private static let animationModeKey = "animationMode"
    private static let animationSecondsKey = "animationDurationSeconds"
    private static let hideModeKey = "hideMode"
    private static let hideSecondsKey = "hideAfterSeconds"
    /// Saved by versions that offered whole minutes only; read when `hideSecondsKey` is missing.
    private static let legacyHideMinutesKey = "hideAfterMinutes"
    private static let showsNamePlateKey = "showsNamePlate"
    private static let namePlateFieldsKey = "namePlateFields"

    /// The choices for `animationSeconds`.
    static let animationSecondsChoices = [5, 10, 30, 60]
    static let defaultAnimationSeconds = 10
    /// The choices for `hideSeconds`: 5 s, 30 s, 1 min, 5 min, 15 min, 30 min.
    static let hideSecondsChoices = [5, 30, 60, 300, 900, 1800]
    static let defaultHideSeconds = 300

    /// Which backends the agents are read from. Both by default.
    var backendChoice: BackendChoice {
        didSet {
            defaults.set(backendChoice.rawValue, forKey: Self.backendChoiceKey)
            onChange?()
        }
    }

    /// Whether agents on remote machines (herdr's saved machines, herdr-core's added ones) count, besides this Mac's.
    /// On by default.
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

    /// How long the sheep waits before it hides, one of `hideSecondsChoices`.
    var hideSeconds: Int {
        didSet {
            defaults.set(hideSeconds, forKey: Self.hideSecondsKey)
            onChange?()
        }
    }

    /// Whether a plate under the sheep names the agent it reports. On by default.
    var showsNamePlate: Bool {
        didSet {
            defaults.set(showsNamePlate, forKey: Self.showsNamePlateKey)
            onChange?()
        }
    }

    /// The parts of the name plate that are shown, all by default; never empty (`setNamePlate(_:shown:)`).
    private(set) var namePlateFields: Set<NamePlate.Field> {
        didSet {
            defaults.set(
                NamePlate.Field.allCases.filter(namePlateFields.contains).map(\.rawValue),
                forKey: Self.namePlateFieldsKey)
            onChange?()
        }
    }

    /// The name plate parts to show now: none while the plate is off.
    var shownNamePlateFields: Set<NamePlate.Field> {
        showsNamePlate ? namePlateFields : []
    }

    /// Shows or hides one part of the name plate. Hiding the last one turns the plate off instead, with all parts
    /// shown when it is turned on again, so the plate is never on without parts.
    func setNamePlate(_ field: NamePlate.Field, shown: Bool) {
        if shown {
            namePlateFields.insert(field)
        } else if namePlateFields == [field] {
            showsNamePlate = false
            namePlateFields = NamePlate.Field.all
        } else {
            namePlateFields.remove(field)
        }
    }

    /// Called after a preference changed.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        backendChoice =
            defaults.string(forKey: Self.backendChoiceKey).flatMap { BackendChoice(rawValue: $0) } ?? .both
        watchesRemoteMachines = defaults.object(forKey: Self.watchesRemoteMachinesKey) as? Bool ?? true
        animationMode =
            defaults.string(forKey: Self.animationModeKey).flatMap { AnimationMode(rawValue: $0) } ?? .always
        // A value that isn't offered in the menu (none saved, or edited by hand) falls back to the default.
        let seconds = defaults.integer(forKey: Self.animationSecondsKey)
        animationSeconds = Self.animationSecondsChoices.contains(seconds) ? seconds : Self.defaultAnimationSeconds
        hideMode = defaults.string(forKey: Self.hideModeKey).flatMap { HideMode(rawValue: $0) } ?? .never
        let hideSeconds =
            defaults.object(forKey: Self.hideSecondsKey) != nil
            ? defaults.integer(forKey: Self.hideSecondsKey) : defaults.integer(forKey: Self.legacyHideMinutesKey) * 60
        self.hideSeconds = Self.hideSecondsChoices.contains(hideSeconds) ? hideSeconds : Self.defaultHideSeconds
        let fields = Set(
            (defaults.stringArray(forKey: Self.namePlateFieldsKey) ?? []).compactMap(NamePlate.Field.init(rawValue:)))
        // Without a saved part to show (none saved, or edited by hand), the plate shows all of them.
        namePlateFields = fields.isEmpty ? NamePlate.Field.all : fields
        showsNamePlate = defaults.object(forKey: Self.showsNamePlateKey) as? Bool ?? true
    }
}
