import Foundation
import Testing

@testable import Buddr

struct AppBundleTests {
    @Test func hostAppHasExpectedBundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "cz.jsyrovy.buddr")
    }

    @Test func hostAppKnowsItIsRunningTests() {
        #expect(RuntimeEnvironment.isRunningTests)
    }
}
