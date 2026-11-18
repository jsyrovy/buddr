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

    @Test func skipsFilesThatAreNotExecutable() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: root) }
        let notExecutable = root.appendingPathComponent("plain")
        let executable = root.appendingPathComponent("bin")
        for (directory, permissions) in [(notExecutable, 0o644), (executable, 0o755)] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let created = fileManager.createFile(
                atPath: directory.appendingPathComponent("herdr").path, contents: Data("#!/bin/sh\n".utf8),
                attributes: [.posixPermissions: permissions])
            try #require(created)
        }

        // The default check looks at the real file system.
        let locator = HerdrLocator(searchPath: "\(notExecutable.path):\(executable.path)")
        #expect(locator.locate()?.path == executable.appendingPathComponent("herdr").path)
    }
}
