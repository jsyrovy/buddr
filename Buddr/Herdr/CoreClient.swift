import Foundation

enum CoreError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Nothing listens on the socket: herdr-core is not installed, not running, or left a stale socket file.
    case notRunning(socketPath: String)
    case timedOut
    case connectionFailed(reason: String)
    /// herdr-core answered with a JSON-RPC error.
    case api(method: String, kind: String?, message: String)
    case invalidOutput(method: String, reason: String)

    var description: String {
        switch self {
        case .notRunning(let socketPath):
            "hc is not running (nothing listens on \(socketPath))"
        case .timedOut:
            "hc did not answer in time"
        case .connectionFailed(let reason):
            "hc: \(reason)"
        case .api(let method, let kind, let message):
            "\(method): \(message)\(kind.map { " (\($0))" } ?? "")"
        case .invalidOutput(let method, let reason):
            "\(method): unexpected output: \(reason)"
        }
    }
}

/// Finds the socket of the default herdr-core session, following the rules of `hc`: `HC_SOCKET`, else
/// `$XDG_RUNTIME_DIR/herdr-core/<session>.sock`, else `$XDG_STATE_HOME/herdr-core/<session>/<session>.sock` with
/// `~/.local/state` as the state home; the session is `HC_SESSION` or `default`. A GUI app usually has none of these
/// variables, so it reaches `~/.local/state/herdr-core/default/default.sock`. A `socket` set in hc's `config.toml` is
/// not read.
struct CoreLocator: Sendable {
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var homeDirectory: String = NSHomeDirectory()

    var socketPath: String {
        func variable(_ name: String) -> String? {
            environment[name].flatMap { $0.isEmpty ? nil : $0 }
        }
        if let socket = variable("HC_SOCKET") {
            return socket
        }
        let session = variable("HC_SESSION") ?? "default"
        if let runtime = variable("XDG_RUNTIME_DIR") {
            return "\(runtime)/herdr-core/\(session).sock"
        }
        let state = variable("XDG_STATE_HOME") ?? "\(homeDirectory)/.local/state"
        return "\(state)/herdr-core/\(session)/\(session).sock"
    }
}

/// Typed access to the read-only herdr-core API calls Buddr needs (JSON-RPC 2.0, one message per line).
struct CoreClient: Sendable {
    /// The core answers at once on this Mac and doesn't wait for a machine that is not connected.
    static let timeout: Duration = .seconds(5)

    let transport: any CoreTransport

    /// The live terminals of this Mac, then of every connected machine (`machine/t7`), and the added machines.
    func terminals() async throws -> CoreTerminalList {
        try await call("terminal.list")
    }

    private func call<Result: Decodable & Sendable>(_ method: String) async throws -> Result {
        let request = #"{"jsonrpc":"2.0","id":1,"method":"\#(method)","params":{}}"# + "\n"
        let answer = try await transport.request(Data(request.utf8), timeout: Self.timeout)
        return try Self.parseResult(answer, method: method)
    }

    /// Unwraps the `result` of a JSON-RPC response, turning an `error` into `CoreError.api`.
    static func parseResult<Result: Decodable & Sendable>(_ data: Data, method: String) throws -> Result {
        let response: CoreResponse<Result>
        do {
            response = try HerdrClient.decoder.decode(CoreResponse<Result>.self, from: data)
        } catch {
            throw CoreError.invalidOutput(method: method, reason: String(describing: error))
        }
        if let error = response.error {
            throw CoreError.api(method: method, kind: error.data?.kind, message: error.message)
        }
        guard let result = response.result else {
            throw CoreError.invalidOutput(method: method, reason: "neither result nor error")
        }
        return result
    }
}
