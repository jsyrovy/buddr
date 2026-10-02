import Foundation
import Testing

@testable import Buddr

struct HerdrLocatorTests {
    @Test func prefersPathEntriesOverFallbacks() {
        let locator = HerdrLocator(searchPath: "/custom/bin:/usr/bin") { path in
            ["/custom/bin/herdr", "/opt/homebrew/bin/herdr"].contains(path)
        }
        #expect(locator.locate()?.path == "/custom/bin/herdr")
    }

    @Test(arguments: ["/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"])
    func fallsBackToHomebrewLocations(installedAt path: String) {
        // GUI apps typically get a minimal PATH without Homebrew.
        let locator = HerdrLocator(searchPath: "/usr/bin:/bin") { $0 == path }
        #expect(locator.locate()?.path == path)
    }

    @Test func worksWithoutPath() {
        let locator = HerdrLocator(searchPath: nil) { $0 == "/opt/homebrew/bin/herdr" }
        #expect(locator.directories == ["/opt/homebrew/bin", "/usr/local/bin"])
        #expect(locator.locate()?.path == "/opt/homebrew/bin/herdr")
    }

    @Test func searchesEachDirectoryOnce() {
        let locator = HerdrLocator(searchPath: "/opt/homebrew/bin::/usr/bin:/opt/homebrew/bin") { _ in false }
        #expect(locator.directories == ["/opt/homebrew/bin", "/usr/bin", "/usr/local/bin"])
        #expect(locator.locate() == nil)
    }
}
