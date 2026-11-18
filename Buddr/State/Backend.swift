/// A tool whose agents Buddr shows.
enum Backend: String, CaseIterable, Sendable {
    case herdr
    /// herdr-core.
    case hc
    /// Rex (superlogical.com/rex).
    case rex
}

/// Which backends the agents are read from, set in the menu bar.
enum BackendChoice: String, CaseIterable, Sendable {
    case herdr
    case hc
    case rex
    case all

    /// The choice saved as `value`; `both` was saved while there were only herdr and hc, and reads as `all`.
    init?(savedValue value: String) {
        self.init(rawValue: value == "both" ? "all" : value)
    }

    var backends: Set<Backend> {
        switch self {
        case .herdr: [.herdr]
        case .hc: [.hc]
        case .rex: [.rex]
        case .all: Set(Backend.allCases)
        }
    }
}
