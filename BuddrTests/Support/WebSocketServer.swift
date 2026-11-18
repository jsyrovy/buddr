import Darwin
import Foundation
import os

@testable import Buddr

/// A WebSocket server on a Unix socket for one connection: answers the upgrade request with `upgradeAnswer` (by
/// default it accepts), then passes every text message it receives to `respond`, which returns the frames to send
/// back. `nil` closes the connection; a server that should stay silent returns `[]`. Pongs are recorded.
final class WebSocketServer: Sendable {
    enum UpgradeAnswer: Sendable {
        case accept
        /// Answers with this instead of `101 Switching Protocols`.
        case raw(String)
        /// Never answers.
        case silence
    }

    let path: String
    private let listener: Int32
    private let state = OSAllocatedUnfairLock(initialState: (messages: [String](), pongs: [[UInt8]]()))

    init(
        upgrade: UpgradeAnswer = .accept,
        respond: @escaping @Sendable (String) -> [WebSocketProtocol.Frame]? = { _ in [] }
    ) throws {
        path = LineServer.temporaryPath()
        listener = try LineServer.boundSocket(at: path)
        guard listen(listener, 1) == 0 else { throw POSIXError(.init(rawValue: errno)!) }
        let listener = listener
        let state = state
        Thread.detachNewThread {
            let connection = accept(listener, nil, nil)
            guard connection >= 0 else { return }
            defer { close(connection) }
            var buffer: [UInt8] = []
            func receive() -> Bool {
                var chunk = [UInt8](repeating: 0, count: 4096)
                let count = read(connection, &chunk, chunk.count)
                guard count > 0 else { return false }
                buffer += chunk[..<count]
                return true
            }
            func send(_ bytes: [UInt8]) {
                _ = bytes.withUnsafeBytes { write(connection, $0.baseAddress!, bytes.count) }
            }
            let separator = Array("\r\n\r\n".utf8)
            while buffer.firstRange(of: separator) == nil {
                guard receive() else { return }
            }
            let end = buffer.firstRange(of: separator)!
            let head = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
            buffer.removeFirst(end.upperBound)
            switch upgrade {
            case .accept:
                let key = head.split(separator: "\r\n").first { $0.hasPrefix("Sec-WebSocket-Key: ") }?
                    .dropFirst("Sec-WebSocket-Key: ".count)
                let accept = WebSocketProtocol.acceptValue(for: String(key ?? ""))
                send(
                    Array(
                        ("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                            + "Sec-WebSocket-Accept: \(accept)\r\nSec-WebSocket-Protocol: rex.control.v1\r\n\r\n").utf8)
                )
            case .raw(let answer):
                send(Array(answer.utf8))
                return
            case .silence:
                Thread.sleep(forTimeInterval: 5)
                return
            }
            while true {
                guard let frame = try? WebSocketProtocol.takeFrame(from: &buffer, maxPayload: 1 << 20) else {
                    guard receive() else { return }
                    continue
                }
                switch frame.opcode {
                case .text:
                    let message = String(decoding: frame.payload, as: UTF8.self)
                    state.withLock { $0.messages.append(message) }
                    guard let frames = respond(message) else { return }
                    for frame in frames {
                        send(WebSocketProtocol.encode(frame, mask: nil))
                    }
                case .pong:
                    state.withLock { $0.pongs.append(frame.payload) }
                case .close:
                    state.withLock { $0.messages.append("<close>") }
                    return
                default:
                    break
                }
            }
        }
    }

    deinit {
        close(listener)
        unlink(path)
    }

    /// The text messages received, then `<close>` once a close frame came.
    var messages: [String] {
        state.withLock { $0.messages }
    }

    var pongs: [[UInt8]] {
        state.withLock { $0.pongs }
    }

    static func text(_ text: String) -> WebSocketProtocol.Frame {
        WebSocketProtocol.Frame(.text, Array(text.utf8))
    }

    static let welcome = text(
        #"{"type":"welcome","protocol":"rex.control.v1","limits":{"max_message_bytes":1048576},"api_revision":14}"#)

    /// A response to the request `id` with `payload`.
    static func response(_ id: String, _ payload: String) -> WebSocketProtocol.Frame {
        text(#"{"type":"response","id":"\#(id)","seq":0,"payload":\#(payload)}"#)
    }
}
