import Foundation

enum RexError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Nothing listens on the socket: Rex is not installed or its server is not running.
    case notRunning(socketPath: String)
    case timedOut
    case connectionFailed(reason: String)
    /// The server answered a request with an error.
    case api(method: String, code: String, message: String)
    case invalidOutput(method: String, reason: String)

    var description: String {
        switch self {
        case .notRunning(let socketPath):
            "rex is not running (nothing listens on \(socketPath))"
        case .timedOut:
            "rex did not answer in time"
        case .connectionFailed(let reason):
            "rex: \(reason)"
        case .api(let method, let code, let message):
            "\(method): \(message) (\(code))"
        case .invalidOutput(let method, let reason):
            "\(method): unexpected output: \(reason)"
        }
    }

    /// Whether the request named something that is gone by now, such as a block closed in the meantime.
    var isNotFound: Bool {
        if case .api(_, let code, _) = self { code == "not_found" || code == "session_not_found" } else { false }
    }
}

/// A request to Rex's control API.
struct RexRequest: Hashable, Sendable {
    let method: String
    /// The arguments as a JSON object; `nil` for a method that takes none.
    let payload: String?

    static let hosts = RexRequest(method: "hosts.list", payload: nil)

    /// Lets the connection use every session (needed by every method that names one) and lists them. Its events,
    /// which follow, are skipped.
    static let attachAll = RexRequest(method: "session.attach_all", payload: #"{"event_scope":"session"}"#)

    static func blocks(of session: String) -> RexRequest {
        RexRequest(method: "session.list_blocks", payload: #"{"session_id":\#(quoted(session))}"#)
    }

    /// A method of a block, such as the terminal's `program_status`, without arguments.
    static func blockMethod(_ method: String, session: String, block: String) -> RexRequest {
        RexRequest(
            method: "block.method",
            payload: #"{"session_id":\#(quoted(session)),"block_id":\#(quoted(block)),"method":"\#(method)","args":{}}"#
        )
    }

    /// The request message with `id`.
    func message(id: String) -> String {
        #"{"type":"request","id":"\#(id)","method":"\#(method)""# + (payload.map { #","payload":\#($0)"# } ?? "") + "}"
    }

    private static func quoted(_ string: String) -> String {
        // Encoding a string can't fail.
        String(decoding: try! JSONEncoder().encode(string), as: UTF8.self)
    }
}

/// A connection to a Rex server. Abstracted so the fetcher can be tested without a server.
protocol RexConnection: AnyObject {
    /// Sends all requests at once and returns the response message of each, in their order. The server may answer
    /// them in any order.
    func call(_ requests: [RexRequest], until deadline: ContinuousClock.Instant) throws -> [Data]
    func close()
}

/// Opens connections to one Rex server.
protocol RexConnector: Sendable {
    func connect(until deadline: ContinuousClock.Instant) throws -> any RexConnection
}

/// Rex's control connection over the Unix socket of a server: a WebSocket at `/api/control` with the subprotocol
/// `rex.control.v1`, one JSON message per text message, opened with a `hello` that the server answers with a
/// `welcome`.
///
/// Nothing is started: a socket nobody listens on is `RexError.notRunning`.
struct RexSocketConnector: RexConnector {
    /// The API revision whose shapes Buddr reads (Rex 0.1.0-preview.19); newer servers translate.
    static let apiRevision = 14

    let path: String

    func connect(until deadline: ContinuousClock.Instant) throws -> any RexConnection {
        try mappingFailures {
            let socket = try WebSocketConnection(
                socketPath: path, path: "/api/control", subprotocol: "rex.control.v1", until: deadline)
            let connection = RexSocketConnection(socket: socket, path: path)
            do {
                try socket.send(Self.hello, until: deadline)
                let welcome = try socket.receive(until: deadline)
                let head = try JSONDecoder.snakeCase.decode(RexMessageHead.self, from: Data(welcome.utf8))
                guard head.type == "welcome", head.protocol == "rex.control.v1" else {
                    throw RexError.connectionFailed(reason: "expected a welcome, got \(welcome.prefix(200))")
                }
            } catch {
                connection.close()
                throw error
            }
            return connection
        }
    }

    /// Who connects, for showing to people.
    private static var hello: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return #"{"type":"hello","api_revision":\#(apiRevision),"#
            + #""client":{"kind":"other","platform":"macos","name":"Buddr","version":"\#(version)"}}"#
    }

    /// Turns the failures of the socket and the WebSocket into `RexError`.
    fileprivate func mappingFailures<Result>(_ body: () throws -> Result) throws -> Result {
        do {
            return try body()
        } catch let failure as UnixSocket.Failure {
            switch failure {
            case .notListening: throw RexError.notRunning(socketPath: path)
            case .timedOut: throw RexError.timedOut
            case .failed(let reason): throw RexError.connectionFailed(reason: reason)
            }
        } catch let error as WebSocketError {
            throw RexError.connectionFailed(reason: error.description)
        } catch let error as DecodingError {
            throw RexError.connectionFailed(reason: "unexpected message: \(error)")
        }
    }
}

final class RexSocketConnection: RexConnection {
    private let socket: WebSocketConnection
    private let connector: RexSocketConnector
    private var lastID = 0

    init(socket: WebSocketConnection, path: String) {
        self.socket = socket
        connector = RexSocketConnector(path: path)
    }

    func call(_ requests: [RexRequest], until deadline: ContinuousClock.Instant) throws -> [Data] {
        try connector.mappingFailures {
            let ids = requests.map { _ in
                lastID += 1
                return String(lastID)
            }
            for (request, id) in zip(requests, ids) {
                try socket.send(request.message(id: id), until: deadline)
            }
            var answers: [String: Data] = [:]
            while answers.count < ids.count {
                let message = Data(try socket.receive(until: deadline).utf8)
                let head = try JSONDecoder.snakeCase.decode(RexMessageHead.self, from: message)
                // Events and messages of types added later are skipped.
                if head.type == "response", let id = head.id, ids.contains(id) {
                    answers[id] = message
                }
            }
            return ids.map { answers[$0]! }
        }
    }

    func close() {
        socket.close()
    }
}

/// Unwraps Rex's answers.
enum RexClient {
    /// The `payload` of a response message, or its `error` as `RexError.api`.
    static func payload<Payload: Decodable & Sendable>(
        _: Payload.Type = Payload.self, of message: Data, method: String
    ) throws(RexError) -> Payload {
        let response: RexResponse<Payload>
        do {
            response = try JSONDecoder.snakeCase.decode(RexResponse<Payload>.self, from: message)
        } catch {
            throw RexError.invalidOutput(method: method, reason: String(describing: error))
        }
        if let error = response.error {
            throw RexError.api(method: method, code: error.code, message: error.message)
        }
        guard let payload = response.payload else {
            throw RexError.invalidOutput(method: method, reason: "neither payload nor error")
        }
        return payload
    }

    /// Calls `requests` and unwraps each answer; no call without requests.
    static func call<Payload: Decodable & Sendable>(
        _ requests: [RexRequest], on connection: any RexConnection, until deadline: ContinuousClock.Instant,
        as _: Payload.Type = Payload.self
    ) throws -> [Result<Payload, RexError>] {
        guard !requests.isEmpty else { return [] }
        return try zip(requests, connection.call(requests, until: deadline)).map { request, message in
            Result { () throws(RexError) -> Payload in try payload(of: message, method: request.method) }
        }
    }
}

/// Where Rex's server listens on this Mac.
///
/// `REX_SERVER` (set in Rex's terminals, as `unix://<percent-encoded path>`) if it names a Unix socket, else
/// `~/Library/Application Support/rex/server.sock`. Rex.app forwards the servers of its SSH hosts to sockets in
/// `ssh/` next to it (`RexTunnels`).
struct RexLocator: Sendable {
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var homeDirectory: String = NSHomeDirectory()

    var socketPath: String {
        if let server = environment["REX_SERVER"], server.hasPrefix("unix://"),
            let path = String(server.dropFirst("unix://".count)).removingPercentEncoding, !path.isEmpty
        {
            return path
        }
        return "\(homeDirectory)/Library/Application Support/rex/server.sock"
    }

    /// Where Rex.app puts the local ends of its SSH tunnels.
    var tunnelDirectory: String {
        (socketPath as NSString).deletingLastPathComponent + "/ssh"
    }
}
