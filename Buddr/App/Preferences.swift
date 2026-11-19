import Foundation
import Observation

/// User preferences shown in the menu bar, saved in `UserDefaults`.
@MainActor
@Observable
final class Preferences {
    // Keys, choices and defaults of the settings that change the cost (all but the name plate and the update check)
    // are mirrored in `Settings.read()` of scripts/measure.swift.
    private static let buddyChoiceKey = "buddy"
    private static let buddyTurnMinutesKey = "buddyTurnMinutes"
    private static let shownBuddyKey = "shownBuddy"
    private static let backendsKey = "agentBackends"
    private static let watchesRemoteMachinesKey = "watchesRemoteMachines"
    private static let animationModeKey = "animationMode"
    private static let animationSecondsKey = "animationDurationSeconds"
    private static let hideModeKey = "hideMode"
    private static let hideMinutesKey = "hideAfterMinutes"
    private static let showsNamePlateKey = "showsNamePlate"
    private static let namePlateFieldsKey = "namePlateFields"
    private static let checksForUpdatesKey = "checksForUpdates"

    /// The choices for `buddyTurnMinutes`.
    static let buddyTurnMinutesChoices = [15, 30, 60]
    static let defaultBuddyTurnMinutes = 30
    /// The choices for `animationSeconds`.
    static let animationSecondsChoices = [5, 10, 30, 60]
    static let defaultAnimationSeconds = 10
    /// The choices for `hideMinutes`.
    static let hideMinutesChoices = [1, 5, 15, 30]
    static let defaultHideMinutes = 5

    /// Which buddy sits on the screen, or whether they take turns. The sheep by default.
    var buddyChoice: BuddyChoice {
        didSet {
            defaults.set(buddyChoice.rawValue, forKey: Self.buddyChoiceKey)
            onChange?()
        }
    }

    /// How long a buddy's turn lasts while they take turns, one of `buddyTurnMinutesChoices`.
    var buddyTurnMinutes: Int {
        didSet {
            defaults.set(buddyTurnMinutes, forKey: Self.buddyTurnMinutesKey)
            onChange?()
        }
    }

    /// The buddy on the screen (or on its way there), named in the menu bar list; taking turns goes on with it after a
    /// restart. Not a setting: saved without `onChange`.
    var shownBuddy: BuddyID {
        didSet {
            defaults.set(shownBuddy.rawValue, forKey: Self.shownBuddyKey)
        }
    }

    /// The buddy to show at launch: the chosen one, or the one shown last while they take turns.
    var buddyAtLaunch: BuddyID {
        switch buddyChoice {
        case .one(let id): id
        case .takingTurns: shownBuddy
        }
    }

    /// Which backends the agents are read from, all by default; never empty (`setBackend(_:read:)`).
    private(set) var backends: Set<Backend> {
        didSet {
            defaults.set(Backend.allCases.filter(backends.contains).map(\.rawValue), forKey: Self.backendsKey)
            onChange?()
        }
    }

    /// Reads agents from one backend or stops reading them. The last backend read can't be dropped
    /// (`canStopReading(_:)`), so agents are always read from somewhere.
    func setBackend(_ backend: Backend, read: Bool) {
        if read {
            backends.insert(backend)
        } else if canStopReading(backend) {
            backends.remove(backend)
        }
    }

    /// Whether agents can stop being read from `backend`: not from the last one read.
    func canStopReading(_ backend: Backend) -> Bool {
        backends != [backend]
    }

    /// Whether agents on remote machines (herdr's saved machines, herdr-core's added ones) count, besides this Mac's.
    /// On by default.
    var watchesRemoteMachines: Bool {
        didSet {
            defaults.set(watchesRemoteMachines, forKey: Self.watchesRemoteMachinesKey)
            onChange?()
        }
    }

    /// When the buddy moves. Always by default.
    var animationMode: AnimationMode {
        didSet {
            defaults.set(animationMode.rawValue, forKey: Self.animationModeKey)
            onChange?()
        }
    }

    /// How long the buddy moves after a change in the `onChange` mode, one of `animationSecondsChoices`.
    var animationSeconds: Int {
        didSet {
            defaults.set(animationSeconds, forKey: Self.animationSecondsKey)
            onChange?()
        }
    }

    /// When the buddy hides on its own. Never by default.
    var hideMode: HideMode {
        didSet {
            defaults.set(hideMode.rawValue, forKey: Self.hideModeKey)
            onChange?()
        }
    }

    /// How long the buddy waits before it hides, one of `hideMinutesChoices`.
    var hideMinutes: Int {
        didSet {
            defaults.set(hideMinutes, forKey: Self.hideMinutesKey)
            onChange?()
        }
    }

    /// Whether a plate under the buddy names the agent it reports. On by default.
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

    /// Whether GitHub is asked for a newer release once a day. Off by default: it is the app's only connection to the
    /// internet.
    var checksForUpdates: Bool {
        didSet {
            defaults.set(checksForUpdates, forKey: Self.checksForUpdatesKey)
            onChange?()
        }
    }

    /// Called after a preference changed.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A buddy that isn't there (anymore) falls back to the sheep.
        buddyChoice =
            defaults.string(forKey: Self.buddyChoiceKey).flatMap { BuddyChoice(rawValue: $0) } ?? .one(.sheep)
        let turnMinutes = defaults.integer(forKey: Self.buddyTurnMinutesKey)
        buddyTurnMinutes =
            Self.buddyTurnMinutesChoices.contains(turnMinutes) ? turnMinutes : Self.defaultBuddyTurnMinutes
        shownBuddy = defaults.string(forKey: Self.shownBuddyKey).flatMap { BuddyID(rawValue: $0) } ?? .sheep
        backends = Self.savedBackends(in: defaults)
        watchesRemoteMachines = defaults.object(forKey: Self.watchesRemoteMachinesKey) as? Bool ?? true
        animationMode =
            defaults.string(forKey: Self.animationModeKey).flatMap { AnimationMode(rawValue: $0) } ?? .always
        // A value that isn't offered in the menu (none saved, or edited by hand) falls back to the default.
        let seconds = defaults.integer(forKey: Self.animationSecondsKey)
        animationSeconds = Self.animationSecondsChoices.contains(seconds) ? seconds : Self.defaultAnimationSeconds
        hideMode = defaults.string(forKey: Self.hideModeKey).flatMap { HideMode(rawValue: $0) } ?? .never
        let minutes = defaults.integer(forKey: Self.hideMinutesKey)
        hideMinutes = Self.hideMinutesChoices.contains(minutes) ? minutes : Self.defaultHideMinutes
        let fields = Set(
            (defaults.stringArray(forKey: Self.namePlateFieldsKey) ?? []).compactMap(NamePlate.Field.init(rawValue:)))
        // Without a saved part to show (none saved, or edited by hand), the plate shows all of them.
        namePlateFields = fields.isEmpty ? NamePlate.Field.all : fields
        showsNamePlate = defaults.object(forKey: Self.showsNamePlateKey) as? Bool ?? true
        checksForUpdates = defaults.bool(forKey: Self.checksForUpdatesKey)
    }

    /// The backends saved as an array of their names. Before they were checkboxes, one choice was saved as a string:
    /// a backend's name or `all` (`both` while there were only herdr and hc). Without a backend (none saved, or edited
    /// by hand), all are read.
    private static func savedBackends(in defaults: UserDefaults) -> Set<Backend> {
        let names = defaults.stringArray(forKey: backendsKey) ?? defaults.string(forKey: backendsKey).map { [$0] } ?? []
        let backends = Set(names.compactMap(Backend.init(rawValue:)))
        return backends.isEmpty ? Backend.all : backends
    }
}
