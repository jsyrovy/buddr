// Decodable shapes of herdr-core API answers (`hc schema` has the full ones). Only the fields Buddr uses are declared.

/// A JSON-RPC response.
struct CoreResponse<Result: Decodable & Sendable>: Decodable, Sendable {
    let result: Result?
    let error: CoreErrorBody?
}

struct CoreErrorBody: Decodable, Sendable {
    struct Details: Decodable, Sendable {
        /// A stable name of the error, such as `not_found`.
        let kind: String?
    }

    let message: String
    let data: Details?
}

/// `result` of `terminal.list`
struct CoreTerminalList: Decodable, Sendable, Equatable {
    let terminals: [CoreTerminal]
    /// Missing when no machine was added.
    let machines: [CoreMachine]?
}

struct CoreTerminal: Decodable, Sendable, Equatable {
    struct Foreground: Decodable, Sendable, Equatable {
        let cwd: String?
    }

    /// What the program reported last (OSC 7501); `nil` for programs that never did, such as shells.
    struct Status: Decodable, Sendable, Equatable {
        /// The program's own name, such as `claude-code`.
        let app: String?
        /// `idle`, `working`, `done`, `blocked` or `error`.
        let state: String
    }

    /// `t7` on this Mac, `machine/t7` on a machine.
    let address: String
    let cwd: String?
    /// What runs in it now.
    let foreground: Foreground?
    /// Free-form; herdr-app sets `where` (`workspace / tab`) and `herdr.space` (the workspace ID).
    let labels: [String: String]?
    let status: Status?
    /// When the status was reported, in ms since the epoch by the clock of the terminal's machine.
    let statusMs: UInt64?
    let title: String?
}

/// A machine added to herdr-core, as `terminal.list` lists it.
struct CoreMachine: Decodable, Sendable, Equatable {
    /// What herdr-core calls it: `rohan` in `rohan/t7`.
    let name: String
    /// `connecting`, `connected`, `needs_login` or `unreachable`.
    let state: String
    /// Why it is not connected, if known.
    let why: String?
}
