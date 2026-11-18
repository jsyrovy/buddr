/// A tool whose agents Buddr shows.
enum Backend: String, CaseIterable, Sendable {
    case herdr
    /// herdr-core.
    case hc
    /// Rex (superlogical.com/rex).
    case rex

    static let all = Set(allCases)
}
