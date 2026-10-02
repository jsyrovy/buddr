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
}
