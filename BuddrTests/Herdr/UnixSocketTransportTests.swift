import Darwin
import Foundation
import Testing
import os

@testable import Buddr

/// Talks to real Unix sockets served by `LineServer`.
struct UnixSocketTransportTests {
    private static let request = Data("{\"method\":\"terminal.list\"}\n".utf8)

    @Test func sendsTheLineAndReturnsTheAnswerWithoutTheNewline() async throws {
        let server = try LineServer { _ in [Data("{\"result\":".utf8), Data("{}}\n{\"ignored\":1}\n".utf8)] }
        let answer = try await UnixSocketTransport(path: server.path).request(Self.request, timeout: .seconds(5))

        #expect(String(decoding: answer, as: UTF8.self) == "{\"result\":{}}")
        #expect(server.received() == Self.request)
    }

    @Test func missingSocketMeansNotRunning() async {
        let path = LineServer.temporaryPath()
        await #expect(throws: CoreError.notRunning(socketPath: path)) {
            try await UnixSocketTransport(path: path).request(Self.request, timeout: .seconds(5))
        }
    }

    @Test func staleSocketFileMeansNotRunning() async throws {
        // A socket that was bound but nobody listens on, like the file of a core that crashed.
        let path = LineServer.temporaryPath()
        let socket = try LineServer.boundSocket(at: path)
        close(socket)
        defer { unlink(path) }

        await #expect(throws: CoreError.notRunning(socketPath: path)) {
            try await UnixSocketTransport(path: path).request(Self.request, timeout: .seconds(5))
        }
    }

    @Test func silentServerTimesOut() async throws {
        let server = try LineServer { _ in nil }
        let start = ContinuousClock.now

        await #expect(throws: CoreError.timedOut) {
            try await UnixSocketTransport(path: server.path).request(Self.request, timeout: .milliseconds(300))
        }
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test func connectionClosedWithoutAnAnswerFails() async throws {
        let server = try LineServer { _ in [] }

        await #expect(
            throws: CoreError.connectionFailed(reason: "herdr-core closed the connection without an answer")
        ) {
            try await UnixSocketTransport(path: server.path).request(Self.request, timeout: .seconds(5))
        }
    }

    @Test func cancellationStopsWaiting() async throws {
        let server = try LineServer { _ in nil }
        let task = Task {
            try await UnixSocketTransport(path: server.path).request(Self.request, timeout: .seconds(30))
        }
        let start = ContinuousClock.now
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test func tooLongPathFails() async {
        let path = "/tmp/" + String(repeating: "x", count: 200)
        await #expect(throws: CoreError.connectionFailed(reason: "socket path longer than 103 bytes: \(path)")) {
            try await UnixSocketTransport(path: path).request(Self.request, timeout: .seconds(5))
        }
    }
}

/// A Unix socket server for one connection: reads the request line, then writes the chunks `respond` returns and
/// closes the connection – or, for `nil`, keeps it open without answering until the server is released.
final class LineServer: Sendable {
    let path: String
    private let listener: Int32
    private let request = OSAllocatedUnfairLock<Data?>(initialState: nil)

    init(respond: @escaping @Sendable (Data) -> [Data]?) throws {
        path = Self.temporaryPath()
        listener = try Self.boundSocket(at: path)
        guard listen(listener, 1) == 0 else { throw POSIXError(.init(rawValue: errno)!) }
        let listener = listener
        let request = request
        Thread.detachNewThread {
            let connection = accept(listener, nil, nil)
            guard connection >= 0 else { return }
            var received = Data()
            var byte: UInt8 = 0
            while read(connection, &byte, 1) == 1 {
                received.append(byte)
                if byte == UInt8(ascii: "\n") { break }
            }
            request.withLock { [received] in $0 = received }
            guard let chunks = respond(received) else {
                // Hold the connection open; the client gives up on its own.
                Thread.sleep(forTimeInterval: 5)
                close(connection)
                return
            }
            for chunk in chunks {
                _ = chunk.withUnsafeBytes { write(connection, $0.baseAddress!, chunk.count) }
            }
            close(connection)
        }
    }

    deinit {
        close(listener)
        unlink(path)
    }

    /// The request line the server read, once it has read it.
    func received() -> Data? {
        request.withLock { $0 }
    }

    /// A fresh path short enough for `sockaddr_un`.
    static func temporaryPath() -> String {
        "/tmp/buddr-test-\(UUID().uuidString.prefix(8)).sock"
    }

    static func boundSocket(at path: String) throws -> Int32 {
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        var address = try UnixSocketTransport.address(for: path)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw POSIXError(.init(rawValue: errno)!) }
        return socket
    }
}
