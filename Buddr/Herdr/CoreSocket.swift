import Foundation

/// Sends one request line to herdr-core and returns the one-line answer. Abstracted so the herdr-core client can be
/// tested without a running core.
protocol CoreTransport: Sendable {
    func request(_ line: Data, timeout: Duration) async throws -> Data
}

/// One request over herdr-core's Unix socket: connect, write the line, read up to the first newline, close.
///
/// Talking to the socket instead of running `hc` matters: every `hc` command starts the core when it isn't running,
/// while a socket nobody listens on just fails (`CoreError.notRunning`). The timeout and task cancellation are noticed
/// while waiting (`UnixSocket`).
struct UnixSocketTransport: CoreTransport {
    /// Answers longer than this are refused instead of growing the buffer without end.
    static let maxAnswerLength = 16 << 20

    let path: String

    @concurrent
    func request(_ line: Data, timeout: Duration) async throws -> Data {
        let deadline = ContinuousClock.now + timeout
        do {
            let socket = try UnixSocket.connect(to: path, until: deadline)
            defer { socket.close() }
            try socket.write(line, until: deadline)
            return try readLine(from: socket, until: deadline)
        } catch let failure as UnixSocket.Failure {
            switch failure {
            case .notListening: throw CoreError.notRunning(socketPath: path)
            case .timedOut: throw CoreError.timedOut
            case .failed(let reason): throw CoreError.connectionFailed(reason: reason)
            }
        }
    }

    private func readLine(from socket: UnixSocket, until deadline: ContinuousClock.Instant) throws -> Data {
        var answer = Data()
        while true {
            guard let received = try socket.read(until: deadline) else {
                throw CoreError.connectionFailed(reason: "herdr-core closed the connection without an answer")
            }
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
}
