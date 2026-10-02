import Foundation
import os

struct ProcessOutput: Sendable, Equatable {
    var exitStatus: Int32
    var stdout: Data
    var stderr: Data
}

enum ProcessRunnerError: Error, Equatable, Sendable {
    case launchFailed(String)
    case timedOut(Duration)
}

/// Runs a command and collects its output. Abstracted so the herdr client can be tested without herdr.
protocol CommandRunning: Sendable {
    func run(_ executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessOutput
}

/// Runs subprocesses with `stdin = /dev/null` and a hard timeout.
///
/// On timeout the process group gets SIGTERM and, if the process is still alive after `killGracePeriod`, SIGKILL.
/// Cancelling the calling task kills the process group. The timeout watcher is a task that holds no pipes, so it never
/// delays reading the output. A grandchild that inherited stdout and detached from the group can keep the pipe open
/// after the process itself exited; output is only awaited for `outputGracePeriod` after exit.
struct ProcessRunner: CommandRunning {
    var killGracePeriod: Duration = .seconds(1)
    var outputGracePeriod: Duration = .milliseconds(500)

    @concurrent
    func run(_ executable: URL, arguments: [String], timeout: Duration) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdout = PipeCollector(stdoutPipe.fileHandleForReading)
        let stderr = PipeCollector(stderrPipe.fileHandleForReading)
        let exited = OneShotSignal()
        process.terminationHandler = { _ in exited.fire() }

        do {
            try process.run()
        } catch {
            _ = stdout.stop()
            _ = stderr.stop()
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        let pid = process.processIdentifier
        let killGracePeriod = killGracePeriod
        /// Returns whether the process had to be stopped because of the timeout.
        let watchdog = Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return false  // The process exited in time.
            }
            guard !exited.hasFired else { return false }
            Self.signalProcessGroup(of: pid, SIGTERM)
            await exited.wait(timeout: killGracePeriod)
            if !exited.hasFired {
                Self.signalProcessGroup(of: pid, SIGKILL)
            }
            return true
        }

        await withTaskCancellationHandler {
            await exited.wait()
        } onCancel: {
            if !exited.hasFired {
                Self.signalProcessGroup(of: pid, SIGKILL)
            }
        }
        watchdog.cancel()
        if Task.isCancelled {
            _ = stdout.stop()
            _ = stderr.stop()
            throw CancellationError()
        }

        async let stdoutEnded: Void = stdout.ended.wait(timeout: outputGracePeriod)
        async let stderrEnded: Void = stderr.ended.wait(timeout: outputGracePeriod)
        _ = await (stdoutEnded, stderrEnded)
        let output = ProcessOutput(exitStatus: process.terminationStatus, stdout: stdout.stop(), stderr: stderr.stop())

        if await watchdog.value {
            throw ProcessRunnerError.timedOut(timeout)
        }
        return output
    }

    /// Foundation starts the child as the leader of its own process group, so signalling the group also stops
    /// grandchildren (such as `ssh`) that would otherwise survive and keep the output pipes open.
    private static func signalProcessGroup(of pid: pid_t, _ signal: Int32) {
        if kill(-pid, signal) != 0 {
            kill(pid, signal)
        }
    }
}

/// Collects everything written to a pipe until EOF or until `stop()` is called.
private final class PipeCollector: Sendable {
    let ended = OneShotSignal()
    private let handle: FileHandle
    private let data = OSAllocatedUnfairLock(initialState: Data())

    init(_ handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [data, ended] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                ended.fire()
            } else {
                data.withLock { $0.append(chunk) }
            }
        }
    }

    /// Stops reading and returns what was collected. The file handle closes itself when released; it is not closed
    /// here because a readability callback may still be running.
    func stop() -> Data {
        handle.readabilityHandler = nil
        return data.withLock { $0 }
    }
}
