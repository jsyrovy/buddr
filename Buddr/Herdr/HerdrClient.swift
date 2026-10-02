import Foundation

enum HerdrError: Error, Equatable, Sendable, CustomStringConvertible {
    case executableNotFound
    case launchFailed(command: String, reason: String)
    case timedOut(command: String)
    /// herdr answered with an error envelope (`{"error":{"code":…,"message":…}}`).
    case api(command: String, code: String, message: String)
    case commandFailed(command: String, exitStatus: Int32, stderr: String)
    case invalidOutput(command: String, reason: String)

    var description: String {
        switch self {
        case .executableNotFound:
            "herdr not found in PATH, \(HerdrLocator.fallbackDirectories.joined(separator: ", "))"
        case .launchFailed(let command, let reason):
            "\(command): could not launch herdr: \(reason)"
        case .timedOut(let command):
            "\(command): timed out"
        case .api(let command, let code, let message):
            "\(command): \(message) (\(code))"
        case .commandFailed(let command, let exitStatus, let stderr):
            "\(command): exit status \(exitStatus)\(stderr.isEmpty ? "" : ": \(stderr)")"
        case .invalidOutput(let command, let reason):
            "\(command): unexpected output: \(reason)"
        }
    }
}

extension HerdrSource {
    /// Global herdr options that select this source. `--machine` (later) must not be combined with `--session`.
    var arguments: [String] {
        switch self {
        case .localSession(let name): ["--session", name]
        }
    }
}

/// Typed access to the read-only herdr CLI commands Buddr needs.
struct HerdrClient: Sendable {
    let executable: URL
    let runner: any CommandRunning
    let timeout: Duration

    func sessions() async throws -> [HerdrSession] {
        try await run(["session", "list", "--json"], parse: Self.parseSessions)
    }

    func agents(on source: HerdrSource) async throws -> [HerdrAgent] {
        let list: HerdrAgentList = try await run(source.arguments + ["agent", "list"], parse: Self.parseResult)
        return list.agents
    }

    func workspaces(on source: HerdrSource) async throws -> [HerdrWorkspace] {
        let list: HerdrWorkspaceList = try await run(source.arguments + ["workspace", "list"], parse: Self.parseResult)
        return list.workspaces
    }

    /// Runs herdr and parses stdout of a successful run. herdr prints error envelopes to stderr with exit status 1.
    private func run<T>(_ arguments: [String], parse: (Data, String) throws -> T) async throws -> T {
        let command = Self.commandName(arguments)
        let output: ProcessOutput
        do {
            output = try await runner.run(executable, arguments: arguments, timeout: timeout)
        } catch ProcessRunnerError.timedOut {
            throw HerdrError.timedOut(command: command)
        } catch ProcessRunnerError.launchFailed(let reason) {
            throw HerdrError.launchFailed(command: command, reason: reason)
        }
        guard output.exitStatus == 0 else {
            if let response = try? Self.decoder.decode(HerdrResponse<HerdrEmpty>.self, from: output.stderr),
                let error = response.error
            {
                throw HerdrError.api(command: command, code: error.code, message: error.message)
            }
            let stderr = String(decoding: output.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw HerdrError.commandFailed(command: command, exitStatus: output.exitStatus, stderr: stderr)
        }
        return try parse(output.stdout, command)
    }

    // MARK: Parsing

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func parseSessions(_ data: Data, command: String = "session list") throws -> [HerdrSession] {
        try decode(HerdrSessionList.self, from: data, command: command).sessions
    }

    /// Unwraps the `result` of an API response envelope, turning an `error` into `HerdrError.api`.
    static func parseResult<Result: Decodable & Sendable>(_ data: Data, command: String) throws -> Result {
        let response = try decode(HerdrResponse<Result>.self, from: data, command: command)
        if let error = response.error {
            throw HerdrError.api(command: command, code: error.code, message: error.message)
        }
        guard let result = response.result else {
            throw HerdrError.invalidOutput(command: command, reason: "neither result nor error")
        }
        return result
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, command: String) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw HerdrError.invalidOutput(command: command, reason: String(describing: error))
        }
    }

    /// Human-readable command for error messages, e.g. `--session default agent list`.
    private static func commandName(_ arguments: [String]) -> String {
        arguments.filter { $0 != "--json" }.joined(separator: " ")
    }
}

/// Placeholder result type for decoding only the error part of an envelope.
private struct HerdrEmpty: Decodable, Sendable {}
