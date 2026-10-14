import Foundation
import Testing

@testable import Buddr

/// Uses one fixed defaults suite, cleared before every test: removing a domain leaves its (empty) plist behind, so a
/// suite per test would pile up files in `~/Library/Preferences`. Serialized because the tests share it.
@MainActor
@Suite(.serialized)
struct PreferencesTests {
    private static let suiteName = "cz.jsyrovy.buddr.tests"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: Self.suiteName)!
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    @Test func watchesRemoteMachinesByDefault() {
        #expect(Preferences(defaults: defaults).watchesRemoteMachines)
    }

    @Test func changeIsSavedAndReported() {
        let preferences = Preferences(defaults: defaults)
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.watchesRemoteMachines = false

        #expect(changes == 1)
        #expect(!Preferences(defaults: defaults).watchesRemoteMachines)
    }

    @Test func animatesAlwaysByDefault() {
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.animationMode == .always)
        #expect(preferences.animationSeconds == Preferences.defaultAnimationSeconds)
    }

    @Test func animationIsSavedAndReported() {
        let preferences = Preferences(defaults: defaults)
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.animationMode = .onChange
        preferences.animationSeconds = 30

        #expect(changes == 2)
        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.animationMode == .onChange)
        #expect(reloaded.animationSeconds == 30)
    }

    @Test func invalidSavedAnimationFallsBackToTheDefaults() {
        defaults.set("sometimes", forKey: "animationMode")
        defaults.set(7, forKey: "animationDurationSeconds")

        let preferences = Preferences(defaults: defaults)

        #expect(preferences.animationMode == .always)
        #expect(preferences.animationSeconds == Preferences.defaultAnimationSeconds)
    }

    @Test func neverHidesByDefault() {
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.hideMode == .never)
        #expect(preferences.hideMinutes == Preferences.defaultHideMinutes)
    }

    @Test func hidingIsSavedAndReported() {
        let preferences = Preferences(defaults: defaults)
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.hideMode = .unlessNeeded
        preferences.hideMinutes = 15

        #expect(changes == 2)
        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.hideMode == .unlessNeeded)
        #expect(reloaded.hideMinutes == 15)
    }

    @Test func invalidSavedHidingFallsBackToTheDefaults() {
        defaults.set("sometimes", forKey: "hideMode")
        defaults.set(7, forKey: "hideAfterMinutes")

        let preferences = Preferences(defaults: defaults)

        #expect(preferences.hideMode == .never)
        #expect(preferences.hideMinutes == Preferences.defaultHideMinutes)
    }

    // MARK: Name plate

    @Test func showsTheWholeNamePlateByDefault() {
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.showsNamePlate)
        #expect(preferences.namePlateFields == NamePlate.Field.all)
        #expect(preferences.shownNamePlateFields == NamePlate.Field.all)
    }

    @Test func namePlateIsSavedAndReported() {
        let preferences = Preferences(defaults: defaults)
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.setNamePlate(.machine, shown: false)
        preferences.showsNamePlate = false

        #expect(changes == 2)
        #expect(preferences.shownNamePlateFields.isEmpty)
        let reloaded = Preferences(defaults: defaults)
        #expect(!reloaded.showsNamePlate)
        #expect(reloaded.namePlateFields == [.workspace, .title])
    }

    @Test func hidingTheLastPartTurnsTheNamePlateOffWithAllPartsForLater() {
        let preferences = Preferences(defaults: defaults)
        preferences.setNamePlate(.machine, shown: false)
        preferences.setNamePlate(.workspace, shown: false)

        preferences.setNamePlate(.title, shown: false)

        #expect(!preferences.showsNamePlate)
        #expect(preferences.namePlateFields == NamePlate.Field.all)
        preferences.showsNamePlate = true
        #expect(preferences.shownNamePlateFields == NamePlate.Field.all)
    }

    @Test func turningTheNamePlateOnKeepsTheChosenParts() {
        let preferences = Preferences(defaults: defaults)
        preferences.setNamePlate(.machine, shown: false)
        preferences.showsNamePlate = false

        preferences.showsNamePlate = true

        #expect(preferences.namePlateFields == [.workspace, .title])
        preferences.setNamePlate(.machine, shown: true)
        #expect(preferences.namePlateFields == NamePlate.Field.all)
    }

    @Test func invalidSavedNamePlatePartsFallBackToAll() {
        defaults.set(["badge"], forKey: "namePlateFields")
        #expect(Preferences(defaults: defaults).namePlateFields == NamePlate.Field.all)
        defaults.set(["title", "badge"], forKey: "namePlateFields")
        #expect(Preferences(defaults: defaults).namePlateFields == [.title])
    }
}
