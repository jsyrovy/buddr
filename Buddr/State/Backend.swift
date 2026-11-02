/// A tool whose agents Buddr shows.
enum Backend: String, Sendable {
    case herdr
    /// herdr-core.
    case hc
}

/// Which backends the agents are read from, set in the menu bar.
enum BackendChoice: String, CaseIterable, Sendable {
    case herdr
    case hc
    case both

    var backends: Set<Backend> {
        switch self {
        case .herdr: [.herdr]
        case .hc: [.hc]
        case .both: [.herdr, .hc]
        }
    }
}
