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
/// On timeout the process gets SIGTERM and, if it is still alive after `killGracePeriod`, SIGKILL. Cancelling the
/// calling task kills the process. The timeout watcher is a task that holds no pipes, so it never delays reading the
/// output. A grandchild that inherited stdout (for example `ssh` started by herdr) can keep the pipe open after the
/// process itself exited; output is only awaited for `outputGracePeriod` after exit.
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
        let exitStatus = OSAllocatedUnfairLock<Int32>(initialState: -1)
        process.terminationHandler = { process in
            exitStatus.withLock { $0 = process.terminationStatus }
            exited.fire()
        }

        do {
            try process.run()
        } catch {
            _ = stdout.stop()
            _ = stderr.stop()
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        let pid = process.processIdentifier
        let timedOut = OSAllocatedUnfairLock(initialState: false)
        let killGracePeriod = killGracePeriod
        let watchdog = Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return  // The process exited in time.
            }
            guard !exited.hasFired else { return }
            timedOut.withLock { $0 = true }
            kill(pid, SIGTERM)
            await exited.wait(timeout: killGracePeriod)
            if !exited.hasFired {
                kill(pid, SIGKILL)
            }
        }

        await withTaskCancellationHandler {
            await exited.wait()
        } onCancel: {
            if !exited.hasFired {
                kill(pid, SIGKILL)
            }
        }
        if Task.isCancelled {
            watchdog.cancel()
            _ = stdout.stop()
            _ = stderr.stop()
            throw CancellationError()
        }
        watchdog.cancel()

        async let stdoutEnded: Void = stdout.ended.wait(timeout: outputGracePeriod)
        async let stderrEnded: Void = stderr.ended.wait(timeout: outputGracePeriod)
        _ = await (stdoutEnded, stderrEnded)
        let output = ProcessOutput(
            exitStatus: exitStatus.withLock { $0 }, stdout: stdout.stop(), stderr: stderr.stop())

        if timedOut.withLock({ $0 }) {
            throw ProcessRunnerError.timedOut(timeout)
        }
        return output
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
