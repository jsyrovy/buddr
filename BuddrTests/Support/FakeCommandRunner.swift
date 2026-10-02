import Foundation
import os

@testable import Buddr

/// A `CommandRunning` that answers herdr invocations with canned output, keyed by the joined arguments.
struct FakeCommandRunner: CommandRunning {
    struct Response: Sendable {
        var result: Result<ProcessOutput, ProcessRunnerError>
        var delay: Duration = .zero

        static func stdout(_ data: Data, delay: Duration = .zero) -> Response {
            Response(result: .success(ProcessOutput(exitStatus: 0, stdout: data, stderr: Data())), delay: delay)
        }

        static func fixture(_ name: String, delay: Duration = .zero) throws -> Response {
            .stdout(try Fixture.data(name), delay: delay)
        }

        static func failure(exitStatus: Int32, stderr: String) -> Response {
            Response(result: .success(ProcessOutput(exitStatus: exitStatus, stdout: Data(), stderr: Data(stderr.utf8))))
        }

        static func error(_ error: ProcessRunnerError) -> Response {
            Response(result: .failure(error))
        }
    }

    var responses: [String: Response]
    private let calls = OSAllocatedUnfairLock<[(key: String, timeout: Duration)]>(initialState: [])

    init(_ responses: [String: Response]) {
        self.responses = responses
    }

    /// Joined arguments of every invocation, in call order.
    var recordedCalls: [String] {
        calls.withLock { $0.map(\.key) }
    }

    /// Timeout of every invocation, keyed by the joined arguments.
    var recordedTimeouts: [String: Duration] {
        calls.withLock { Dictionary($0.map { ($0.key, $0.timeout) }, uniquingKeysWith: { _, last in last }) }
    }

    func run(_ executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessOutput {
        let key = arguments.joined(separator: " ")
        calls.withLock { $0.append((key, timeout)) }
        guard let response = responses[key] else {
            return ProcessOutput(exitStatus: 2, stdout: Data(), stderr: Data("no fake response for \(key)".utf8))
        }
        if response.delay > .zero {
            try await Task.sleep(for: response.delay)
        }
        return try response.result.get()
    }
}
