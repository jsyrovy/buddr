import Foundation
import os

@testable import Buddr

/// A `CommandRunning` that answers herdr invocations with canned output, keyed by the joined arguments.
struct FakeCommandRunner: CommandRunning {
    struct Response: Sendable {
        var result: Result<ProcessOutput, ProcessRunnerError>
        var barrier: CommandBarrier?

        static func stdout(_ data: Data, barrier: CommandBarrier? = nil) -> Response {
            Response(result: .success(ProcessOutput(exitStatus: 0, stdout: data, stderr: Data())), barrier: barrier)
        }

        static func fixture(_ name: String, barrier: CommandBarrier? = nil) throws -> Response {
            .stdout(try Fixture.data(name), barrier: barrier)
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
        await response.barrier?.pass()
        return try response.result.get()
    }
}

/// Holds commands back until `count` of them run at the same time – which commands run one after another never reach.
final class CommandBarrier: Sendable {
    private let remaining: OSAllocatedUnfairLock<Int>
    private let allArrived = OneShotSignal()

    init(count: Int) {
        remaining = OSAllocatedUnfairLock(initialState: count)
    }

    /// Returns once `count` callers have arrived, or as soon as the calling task is cancelled.
    func pass() async {
        let isLast = remaining.withLock { remaining in
            remaining -= 1
            return remaining == 0
        }
        if isLast {
            allArrived.fire()
        }
        await allArrived.wait()
    }
}
