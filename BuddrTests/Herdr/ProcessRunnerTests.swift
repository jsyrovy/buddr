import Foundation
import Testing

@testable import Buddr

/// Runs real processes through `/bin/sh`.
struct ProcessRunnerTests {
    private let shell = URL(fileURLWithPath: "/bin/sh")
    private let clock = ContinuousClock()

    private func sh(
        _ script: String, timeout: Duration = .seconds(5), runner: ProcessRunner = ProcessRunner()
    )
        async throws -> ProcessOutput
    {
        try await runner.run(shell, arguments: ["-c", script], timeout: timeout)
    }

    @Test func collectsStdoutStderrAndExitStatus() async throws {
        let output = try await sh("printf out; printf err >&2; exit 3")
        #expect(output == ProcessOutput(exitStatus: 3, stdout: Data("out".utf8), stderr: Data("err".utf8)))
    }

    @Test func readsOutputLargerThanThePipeBuffer() async throws {
        let output = try await sh("head -c 300000 /dev/zero")
        #expect(output.exitStatus == 0)
        #expect(output.stdout.count == 300_000)
    }

    @Test func stdinIsDevNull() async throws {
        // `cat` would wait forever on an inherited terminal stdin.
        let output = try await sh("cat", timeout: .seconds(2))
        #expect(output.exitStatus == 0)
        #expect(output.stdout.isEmpty)
    }

    @Test func terminatesProcessesThatExceedTheTimeout() async {
        let start = clock.now
        await #expect(throws: ProcessRunnerError.timedOut(.milliseconds(300))) {
            try await sh("sleep 10", timeout: .milliseconds(300))
        }
        #expect(clock.now - start < .seconds(2))
    }

    @Test func killsProcessesThatIgnoreSigterm() async {
        let runner = ProcessRunner(killGracePeriod: .milliseconds(200), outputGracePeriod: .milliseconds(200))
        let start = clock.now
        await #expect(throws: ProcessRunnerError.timedOut(.milliseconds(300))) {
            try await sh("trap '' TERM; sleep 3", timeout: .milliseconds(300), runner: runner)
        }
        #expect(clock.now - start < .seconds(2))
    }

    @Test func doesNotWaitForGrandchildrenHoldingThePipe() async throws {
        // The background `sleep` inherits stdout and keeps it open after `sh` exits.
        let start = clock.now
        let output = try await sh("sleep 3 & printf done", timeout: .seconds(10))
        #expect(output.exitStatus == 0)
        #expect(output.stdout == Data("done".utf8))
        #expect(clock.now - start < .milliseconds(2_000))
    }

    @Test func cancellationKillsTheProcess() async {
        let task = Task { try await sh("sleep 10", timeout: .seconds(20)) }
        try? await Task.sleep(for: .milliseconds(200))
        let start = clock.now
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(clock.now - start < .seconds(1))
    }

    @Test func reportsLaunchFailures() async {
        await #expect {
            try await ProcessRunner().run(
                URL(fileURLWithPath: "/nonexistent/herdr"), arguments: [], timeout: .seconds(1))
        } throws: { error in
            if case ProcessRunnerError.launchFailed = error { true } else { false }
        }
    }
}
