import Foundation

/// Buddr's Homebrew cask (`jsyrovy/tap/buddr`). A copy installed with it should be updated with `brew upgrade`, so
/// Homebrew knows the version it has.
enum HomebrewCask {
    static let upgradeCommand = "brew upgrade --cask jsyrovy/tap/buddr"
    /// Where Homebrew keeps what it knows of the installed cask, on Apple Silicon and on Intel.
    static let caskroomPaths = ["/opt/homebrew/Caskroom/buddr", "/usr/local/Caskroom/buddr"]

    /// Whether the cask is installed, looked up once. It may have put the app elsewhere than the running copy (a
    /// `make install` next to it), so this only suggests the command.
    static let isInstalled = caskroomPaths.contains { FileManager.default.fileExists(atPath: $0) }
}
