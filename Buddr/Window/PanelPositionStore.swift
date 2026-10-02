import CoreGraphics
import Foundation

/// Remembers where the user left the sheep, so it sits there again after the next launch.
enum PanelPositionStore {
    private static let key = "panelOrigin"

    /// The saved panel origin, or `nil` if none was saved (or the stored value is not a point).
    static func load() -> CGPoint? {
        guard let dictionary = UserDefaults.standard.dictionary(forKey: key) else { return nil }
        return CGPoint(dictionaryRepresentation: dictionary as CFDictionary)
    }

    static func save(_ origin: CGPoint) {
        UserDefaults.standard.set(origin.dictionaryRepresentation, forKey: key)
    }
}
