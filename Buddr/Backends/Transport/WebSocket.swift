import CryptoKit
import Foundation

/// Why a WebSocket connection failed.
enum WebSocketError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The server didn't accept the upgrade.
    case handshake(String)
    /// The server broke the protocol, or sent more than allowed.
    case protocolViolation(String)
    /// The server closed the connection, with a close frame (`code`, `reason`) or without one.
    case closed(code: UInt16?, reason: String)

    var description: String {
        switch self {
        case .handshake(let reason): "WebSocket handshake failed: \(reason)"
        case .protocolViolation(let reason): "WebSocket protocol error: \(reason)"
        case .closed(let code?, let reason): "closed the connection (\(code)\(reason.isEmpty ? "" : ": \(reason)"))"
        case .closed(nil, let reason): reason
        }
    }
}

/// The parts of RFC 6455 a client needs, without a socket: the upgrade request and its answer, and frames.
enum WebSocketProtocol {
    enum Opcode: UInt8 {
        case continuation = 0
        case text = 1
        case binary = 2
        case close = 8
        case ping = 9
        case pong = 10
    }

    struct Frame: Equatable, Sendable {
        var isFinal = true
        var opcode: UInt8
        var payload: [UInt8]

        init(isFinal: Bool = true, _ opcode: Opcode, _ payload: [UInt8] = []) {
            self.init(isFinal: isFinal, opcode: opcode.rawValue, payload: payload)
        }

        init(isFinal: Bool, opcode: UInt8, payload: [UInt8]) {
            self.isFinal = isFinal
            self.opcode = opcode
            self.payload = payload
        }
    }

    private static let acceptGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    /// A fresh `Sec-WebSocket-Key`: 16 random bytes in Base64.
    static func makeKey() -> String {
        Data((0..<16).map { _ in UInt8.random(in: .min ... .max) }).base64EncodedString()
    }

    /// The upgrade request for `path`. Over a Unix socket the host name doesn't matter.
    static func upgradeRequest(path: String, key: String, subprotocol: String) -> Data {
        let lines = [
            "GET \(path) HTTP/1.1", "Host: localhost", "Upgrade: websocket", "Connection: Upgrade",
            "Sec-WebSocket-Key: \(key)", "Sec-WebSocket-Version: 13", "Sec-WebSocket-Protocol: \(subprotocol)",
        ]
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    /// The `Sec-WebSocket-Accept` a server answers `key` with.
    static func acceptValue(for key: String) -> String {
        Data(Insecure.SHA1.hash(data: Data((key + acceptGUID).utf8))).base64EncodedString()
    }

    /// Checks the head of the server's answer to the upgrade request (up to the empty line).
    static func checkUpgradeResponse(_ head: String, key: String) throws(WebSocketError) {
        let lines = head.split(separator: "\r\n", omittingEmptySubsequences: false)
        let statusLine = lines.first.map(String.init) ?? ""
        let status = statusLine.split(separator: " ").dropFirst().first
        guard status == "101" else {
            throw .handshake(statusLine.isEmpty ? "empty answer" : statusLine)
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(
                in: .whitespaces)
        }
        guard headers["sec-websocket-accept"] == acceptValue(for: key) else {
            throw .handshake("wrong Sec-WebSocket-Accept")
        }
    }

    /// The frame on the wire. Clients mask every frame (`mask`, 4 bytes); servers don't.
    static func encode(_ frame: Frame, mask: [UInt8]?) -> [UInt8] {
        var bytes: [UInt8] = [(frame.isFinal ? 0x80 : 0) | frame.opcode]
        let maskBit: UInt8 = mask == nil ? 0 : 0x80
        let length = frame.payload.count
        switch length {
        case ..<126:
            bytes.append(maskBit | UInt8(length))
        case ...0xFFFF:
            bytes.append(maskBit | 126)
            bytes += [UInt8(length >> 8), UInt8(length & 0xFF)]
        default:
            bytes.append(maskBit | 127)
            bytes += (0..<8).reversed().map { UInt8((UInt64(length) >> ($0 * 8)) & 0xFF) }
        }
        guard let mask else { return bytes + frame.payload }
        return bytes + mask + frame.payload.enumerated().map { $0.element ^ mask[$0.offset % 4] }
    }

    /// Takes the first complete frame off the front of `buffer` (unmasking it); `nil` while it is incomplete.
    static func takeFrame(from buffer: inout [UInt8], maxPayload: Int) throws(WebSocketError) -> Frame? {
        guard buffer.count >= 2 else { return nil }
        let first = buffer[0]
        let second = buffer[1]
        guard first & 0x70 == 0 else { throw .protocolViolation("reserved bits set") }
        var offset = 2
        var length = UInt64(second & 0x7F)
        if length >= 126 {
            let size = length == 126 ? 2 : 8
            guard buffer.count >= offset + size else { return nil }
            length = buffer[offset..<offset + size].reduce(0) { $0 << 8 | UInt64($1) }
            offset += size
        }
        guard length <= UInt64(maxPayload) else { throw .protocolViolation("frame longer than \(maxPayload) bytes") }
        let isMasked = second & 0x80 != 0
        let mask = isMasked ? Array(buffer.dropFirst(offset).prefix(4)) : []
        offset += isMasked ? 4 : 0
        let end = offset + Int(length)
        guard buffer.count >= end else { return nil }
        var payload = Array(buffer[offset..<end])
        if isMasked {
            for index in payload.indices {
                payload[index] ^= mask[index % 4]
            }
        }
        buffer.removeFirst(end)
        return Frame(isFinal: first & 0x80 != 0, opcode: first & 0x0F, payload: payload)
    }

    /// The payload of a close frame: the status code, then the reason.
    static func closePayload(code: UInt16, reason: String = "") -> [UInt8] {
        [UInt8(code >> 8), UInt8(code & 0xFF)] + Array(reason.utf8)
    }
}

/// A client WebSocket over a Unix socket that sends and receives text messages, one exchange at a time.
///
/// Pings are answered while waiting for a message; binary messages are skipped. The timeout and task cancellation are
/// noticed while waiting (`UnixSocket`), whose failures it passes on.
final class WebSocketConnection {
    /// Neither the head of the upgrade answer nor a message may grow beyond these.
    private static let maxHeadLength = 16 << 10
    let maxMessageLength: Int

    private let socket: UnixSocket
    /// Received bytes not taken as frames yet.
    private var buffer: [UInt8] = []
    private var isClosed = false

    /// Connects to `socketPath` and upgrades the connection to a WebSocket at `path` with `subprotocol`.
    init(
        socketPath: String, path: String, subprotocol: String, maxMessageLength: Int = 16 << 20,
        until deadline: ContinuousClock.Instant
    ) throws {
        self.maxMessageLength = maxMessageLength
        socket = try UnixSocket.connect(to: socketPath, until: deadline)
        let key = WebSocketProtocol.makeKey()
        try socket.write(
            WebSocketProtocol.upgradeRequest(path: path, key: key, subprotocol: subprotocol), until: deadline)
        let separator = Array("\r\n\r\n".utf8)
        while true {
            if let end = buffer.firstRange(of: separator) {
                let head = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
                buffer.removeFirst(end.upperBound)
                try WebSocketProtocol.checkUpgradeResponse(head, key: key)
                return
            }
            guard buffer.count <= Self.maxHeadLength else { throw WebSocketError.handshake("answer too long") }
            guard let received = try socket.read(until: deadline) else {
                throw WebSocketError.handshake("connection closed")
            }
            buffer += received
        }
    }

    deinit {
        socket.close()
    }

    func send(_ text: String, until deadline: ContinuousClock.Instant) throws {
        try send(WebSocketProtocol.Frame(.text, Array(text.utf8)), until: deadline)
    }

    /// The next text message.
    func receive(until deadline: ContinuousClock.Instant) throws -> String {
        // The fragments of a message, and whether it is a text message.
        var fragments: [UInt8] = []
        var isText = false
        while true {
            guard let frame = try WebSocketProtocol.takeFrame(from: &buffer, maxPayload: maxMessageLength) else {
                guard let received = try socket.read(until: deadline) else {
                    throw WebSocketError.closed(code: nil, reason: "closed the connection")
                }
                buffer += received
                continue
            }
            switch WebSocketProtocol.Opcode(rawValue: frame.opcode) {
            case .text, .binary, .continuation:
                if frame.opcode != WebSocketProtocol.Opcode.continuation.rawValue {
                    fragments = []
                    isText = frame.opcode == WebSocketProtocol.Opcode.text.rawValue
                }
                fragments += frame.payload
                guard fragments.count <= maxMessageLength else {
                    throw WebSocketError.protocolViolation("message longer than \(maxMessageLength) bytes")
                }
                if frame.isFinal, isText {
                    return String(decoding: fragments, as: UTF8.self)
                }
            case .ping:
                try send(WebSocketProtocol.Frame(.pong, frame.payload), until: deadline)
            case .pong:
                break
            case .close:
                let code = frame.payload.count >= 2 ? UInt16(frame.payload[0]) << 8 | UInt16(frame.payload[1]) : nil
                let reason = String(decoding: frame.payload.dropFirst(2), as: UTF8.self)
                close(until: deadline)
                throw WebSocketError.closed(code: code, reason: reason)
            case nil:
                throw WebSocketError.protocolViolation("unknown opcode \(frame.opcode)")
            }
        }
    }

    /// Sends a close frame (best effort, without waiting for the answer) and closes the socket. A server that gets
    /// no close frame may keep the client around for a while.
    func close(until deadline: ContinuousClock.Instant = .now + .milliseconds(200)) {
        guard !isClosed else { return }
        isClosed = true
        try? send(WebSocketProtocol.Frame(.close, WebSocketProtocol.closePayload(code: 1000)), until: deadline)
        socket.close()
    }

    private func send(_ frame: WebSocketProtocol.Frame, until deadline: ContinuousClock.Instant) throws {
        let mask = (0..<4).map { _ in UInt8.random(in: .min ... .max) }
        try socket.write(Data(WebSocketProtocol.encode(frame, mask: mask)), until: deadline)
    }
}
