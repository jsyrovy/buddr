import Foundation

/// JSON fixtures from `BuddrTests/Fixtures`, copied into the test bundle as resources.
enum Fixture {
    private final class BundleToken {}

    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    enum FixtureError: Error {
        case missing(String)
    }
}
