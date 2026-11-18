import Darwin
import Foundation

/// A connected, non-blocking Unix domain socket for one request at a time; shared by herdr-core's and Rex's
/// transports.
///
/// The blocking calls wait in `poll` slices, so a deadline and task cancellation (`CancellationError`) are noticed
/// within `pollSlice`. Closed when released.
final class UnixSocket {
    enum Failure: Error, Equatable {
        /// Nothing listens: no socket file, or a stale one left by a server that is gone (`ENOENT`, `ECONNREFUSED`).
        case notListening
        case timedOut
        case failed(reason: String)
    }

    private static let pollSlice: Duration = .milliseconds(100)

    private let descriptor: Int32
    private var isClosed = false

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        close()
    }

    /// Connects to the socket at `path`.
    static func connect(to path: String, until deadline: ContinuousClock.Instant) throws -> UnixSocket {
        var address = try address(for: path)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw Failure.failed(reason: errorText()) }
        let socket = UnixSocket(descriptor: descriptor)
        var noSigpipe: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)

        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if result != 0 {
            switch errno {
            case ENOENT, ECONNREFUSED: throw Failure.notListening
            case EINPROGRESS, EAGAIN:
                try socket.wait(for: Int16(POLLOUT), until: deadline)
                var error: Int32 = 0
                var length = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &length)
                guard error == 0 else { throw Failure.failed(reason: errorText(error)) }
            default: throw Failure.failed(reason: errorText())
            }
        }
        return socket
    }

    /// The address of the socket at `path`.
    static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let pathBytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < capacity else {
            throw Failure.failed(reason: "socket path longer than \(capacity - 1) bytes: \(path)")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: pathBytes)
            buffer[pathBytes.count] = 0
        }
        return address
    }

    /// Writes all of `data`.
    func write(_ data: Data, until deadline: ContinuousClock.Instant) throws {
        var offset = 0
        while offset < data.count {
            let written = data.withUnsafeBytes {
                Darwin.write(descriptor, $0.baseAddress! + offset, data.count - offset)
            }
            if written < 0 {
                guard errno == EAGAIN || errno == EINTR else { throw Failure.failed(reason: Self.errorText()) }
                try wait(for: Int16(POLLOUT), until: deadline)
                continue
            }
            offset += written
        }
    }

    /// The bytes that have arrived, waiting for at least one; `nil` once the other side has closed the connection.
    func read(until deadline: ContinuousClock.Instant) throws -> [UInt8]? {
        var chunk = [UInt8](repeating: 0, count: 16 << 10)
        while true {
            try wait(for: Int16(POLLIN), until: deadline)
            let count = Darwin.read(descriptor, &chunk, chunk.count)
            if count < 0 {
                guard errno == EAGAIN || errno == EINTR else { throw Failure.failed(reason: Self.errorText()) }
                continue
            }
            return count == 0 ? nil : Array(chunk[..<count])
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        Darwin.close(descriptor)
    }

    /// Returns once `events` are ready (or the socket was hung up); throws on timeout and cancellation.
    private func wait(for events: Int16, until deadline: ContinuousClock.Instant) throws {
        while true {
            try Task.checkCancellation()
            let remaining = deadline - ContinuousClock.now
            guard remaining > .zero else { throw Failure.timedOut }
            var pollDescriptor = pollfd(fd: descriptor, events: events, revents: 0)
            let result = poll(&pollDescriptor, 1, Self.milliseconds(min(remaining, Self.pollSlice)))
            if result > 0 { return }
            if result < 0, errno != EINTR {
                throw Failure.failed(reason: Self.errorText())
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
