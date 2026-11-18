// Decodable shapes of Rex's control API (`GET /api/help` or `rex api describe` on a server has the full ones). Only
// the fields Buddr uses are declared; keys are snake_case (`HerdrClient.decoder`).

/// The fields every message has.
struct RexMessageHead: Decodable, Sendable {
    /// `welcome`, `response`, `event`, or one added later.
    let type: String
    /// The request a `response` answers.
    let id: String?
    /// `rex.control.v1` in a `welcome`.
    let `protocol`: String?
}

/// A `response` message.
struct RexResponse<Payload: Decodable & Sendable>: Decodable, Sendable {
    let payload: Payload?
    let error: RexErrorBody?
}

struct RexErrorBody: Decodable, Sendable {
    /// Such as `not_found` or `conflict`.
    let code: String
    let message: String
}

/// The result of `session.attach_all`, in the server's order.
struct RexSessionList: Decodable, Sendable {
    let sessions: [RexSession]?
}

struct RexSession: Decodable, Sendable, Equatable {
    let sessionId: String
    let label: String
}

/// The result of `session.list_blocks`, sorted by `block_id`.
struct RexBlockList: Decodable, Sendable {
    let blocks: [RexBlock]?
}

struct RexBlock: Decodable, Sendable, Equatable {
    let blockId: String?
    /// `com.superlogical.terminal` for terminals.
    let creatorName: String?
}

/// The result of the terminal method `program_status`: what programs reported with OSC 7501.
struct RexProgramStatus: Decodable, Sendable {
    struct Record: Decodable, Sendable, Equatable {
        /// `build/test`; `nil` for the root record.
        let id: String?
        /// `idle`, `working`, `done`, `blocked` or `error`.
        let state: String
        let app: String?
        /// `app`, or that of the nearest parent record that has one.
        let effectiveApp: String?
        /// RFC 3339, by the server's clock.
        let updatedAt: String?
    }

    /// The root record first, each parent before its children.
    let records: [Record]
}

/// The result of the terminal method `title`.
struct RexTitle: Decodable, Sendable {
    let title: String
}

/// The result of the terminal method `pwd`.
struct RexDirectory: Decodable, Sendable {
    /// A `file://` URL (OSC 7) or a plain path; `nil` when none was reported.
    let pwd: String?
}

/// The result of `hosts.list`.
struct RexHostList: Decodable, Sendable {
    let hosts: [RexHost]?
}

struct RexHost: Decodable, Sendable, Equatable {
    let label: String
    /// Such as `ssh://studio`.
    let endpoints: [String]?
}
