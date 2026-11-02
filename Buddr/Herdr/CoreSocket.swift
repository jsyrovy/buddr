import Darwin
import Foundation

/// Sends one request line to herdr-core and returns the one-line answer. Abstracted so the herdr-core client can be
/// tested without a running core.
protocol CoreTransport: Sendable {
    func request(_ line: Data, timeout: Duration) async throws -> Data
}

/// One request over herdr-core's Unix socket: connect, write the line, read up to the first newline, close.
///
/// Talking to the socket instead of running `hc` matters: every `hc` command starts the core when it isn't running,
/// while a socket nobody listens on just fails (`CoreError.notRunning`). The blocking calls wait in `poll` slices, so
/// the timeout and task cancellation are noticed within `pollSlice`.
struct UnixSocketTransport: CoreTransport {
    /// Answers longer than this are refused instead of growing the buffer without end.
    static let maxAnswerLength = 16 << 20
    private static let pollSlice: Duration = .milliseconds(100)

    let path: String

    @concurrent
    func request(_ line: Data, timeout: Duration) async throws -> Data {
        let deadline = ContinuousClock.now + timeout
        let socket = try connect(until: deadline)
        defer { close(socket) }
        // A request line is far smaller than the send buffer of a new connection, so it goes out in one write.
        let written = line.withUnsafeBytes { Darwin.write(socket, $0.baseAddress, line.count) }
        guard written == line.count else {
            throw CoreError.connectionFailed(reason: written < 0 ? Self.errorText() : "request cut short")
        }
        return try readLine(from: socket, until: deadline)
    }

    /// The address of the socket at `path`.
    static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let pathBytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < capacity else {
            throw CoreError.connectionFailed(reason: "socket path longer than \(capacity - 1) bytes: \(path)")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: pathBytes)
            buffer[pathBytes.count] = 0
        }
        return address
    }

    private func connect(until deadline: ContinuousClock.Instant) throws -> Int32 {
        var address = try Self.address(for: path)
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { throw CoreError.connectionFailed(reason: Self.errorText()) }
        var noSigpipe: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(socket, F_SETFD, FD_CLOEXEC)
        _ = fcntl(socket, F_SETFL, fcntl(socket, F_GETFL) | O_NONBLOCK)

        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        do {
            if result != 0 {
                switch errno {
                // No socket file, or a stale one left by a core that is gone.
                case ENOENT, ECONNREFUSED: throw CoreError.notRunning(socketPath: path)
                case EINPROGRESS, EAGAIN:
                    try wait(for: Int16(POLLOUT), on: socket, until: deadline)
                    var error: Int32 = 0
                    var length = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(socket, SOL_SOCKET, SO_ERROR, &error, &length)
                    guard error == 0 else { throw CoreError.connectionFailed(reason: Self.errorText(error)) }
                default: throw CoreError.connectionFailed(reason: Self.errorText())
                }
            }
        } catch {
            close(socket)
            throw error
        }
        return socket
    }

    private func readLine(from socket: Int32, until deadline: ContinuousClock.Instant) throws -> Data {
        var answer = Data()
        var chunk = [UInt8](repeating: 0, count: 16 << 10)
        while true {
            try wait(for: Int16(POLLIN), on: socket, until: deadline)
            let count = Darwin.read(socket, &chunk, chunk.count)
            if count < 0 {
                guard errno == EAGAIN || errno == EINTR else {
                    throw CoreError.connectionFailed(reason: Self.errorText())
                }
                continue
            }
            guard count > 0 else {
                throw CoreError.connectionFailed(reason: "herdr-core closed the connection without an answer")
            }
            let received = chunk[..<count]
            if let newline = received.firstIndex(of: UInt8(ascii: "\n")) {
                answer.append(contentsOf: received[..<newline])
                return answer
            }
            answer.append(contentsOf: received)
            guard answer.count <= Self.maxAnswerLength else {
                throw CoreError.connectionFailed(reason: "answer longer than \(Self.maxAnswerLength) bytes")
            }
        }
    }

    /// Returns once `events` are ready on `socket` (or it was hung up); throws on timeout and cancellation.
    private func wait(for events: Int16, on socket: Int32, until deadline: ContinuousClock.Instant) throws {
        while true {
            try Task.checkCancellation()
            let remaining = deadline - ContinuousClock.now
            guard remaining > .zero else { throw CoreError.timedOut }
            var descriptor = pollfd(fd: socket, events: events, revents: 0)
            let result = poll(&descriptor, 1, Self.milliseconds(min(remaining, Self.pollSlice)))
            if result > 0 { return }
            if result < 0, errno != EINTR {
                throw CoreError.connectionFailed(reason: Self.errorText())
            }
        }
    }

    private static func milliseconds(_ duration: Duration) -> Int32 {
        let (seconds, attoseconds) = duration.components
        return Int32(max(1, seconds * 1000 + attoseconds / 1_000_000_000_000_000))
    }

    private static func errorText(_ code: Int32 = errno) -> String {
        String(cString: strerror(code))
    }
}
