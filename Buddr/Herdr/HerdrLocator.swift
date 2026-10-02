import Foundation

/// Finds the `herdr` executable.
///
/// GUI apps don't inherit the shell `PATH`, so the usual Homebrew locations are searched as well.
struct HerdrLocator: Sendable {
    static let fallbackDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]

    var searchPath: String?
    var isExecutable: @Sendable (String) -> Bool

    init(
        searchPath: String? = ProcessInfo.processInfo.environment["PATH"],
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.searchPath = searchPath
        self.isExecutable = isExecutable
    }

    /// Directories searched in order: `PATH` entries first, then the fallbacks.
    var directories: [String] {
        let pathDirectories = (searchPath ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (pathDirectories + Self.fallbackDirectories).filter { seen.insert($0).inserted }
    }

    func locate() -> URL? {
        for directory in directories {
            let url = URL(fileURLWithPath: directory, isDirectory: true).appendingPathComponent("herdr")
            if isExecutable(url.path) {
                return url
            }
        }
        return nil
    }
}
