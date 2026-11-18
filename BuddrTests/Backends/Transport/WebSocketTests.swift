import Foundation
import Testing

@testable import Buddr

struct WebSocketProtocolTests {
    @Test func acceptValueFollowsTheRFC() {
        // The example of RFC 6455, section 1.3.
        #expect(WebSocketProtocol.acceptValue(for: "dGhlIHNhbXBsZSBub25jZQ==") == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    }

    @Test func upgradeRequestAsksForTheSubprotocol() {
        let request = String(
            decoding: WebSocketProtocol.upgradeRequest(path: "/api/control", key: "abc", subprotocol: "rex.control.v1"),
            as: UTF8.self)

        #expect(request.hasPrefix("GET /api/control HTTP/1.1\r\n"))
        #expect(request.contains("\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: abc\r\n"))
        #expect(request.contains("\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: rex.control.v1\r\n"))
        #expect(request.hasSuffix("\r\n\r\n"))
    }

    @Test func keysAreSixteenRandomBytes() {
        let key = WebSocketProtocol.makeKey()
        #expect(Data(base64Encoded: key)?.count == 16)
        #expect(key != WebSocketProtocol.makeKey())
    }

    @Test func upgradeResponseMustSwitchWithTheRightAcceptValue() throws {
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        try WebSocketProtocol.checkUpgradeResponse(
            "HTTP/1.1 101 Switching Protocols\r\nupgrade: websocket\r\nsec-websocket-accept:  s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
            key: key)

        #expect(throws: WebSocketError.handshake("HTTP/1.1 426 Upgrade Required")) {
            try WebSocketProtocol.checkUpgradeResponse("HTTP/1.1 426 Upgrade Required\r\nUpgrade: websocket", key: key)
        }
        #expect(throws: WebSocketError.handshake("wrong Sec-WebSocket-Accept")) {
            try WebSocketProtocol.checkUpgradeResponse(
                "HTTP/1.1 101 Switching Protocols\r\nSec-WebSocket-Accept: x", key: key)
        }
        #expect(throws: WebSocketError.handshake("empty answer")) {
            try WebSocketProtocol.checkUpgradeResponse("", key: key)
        }
    }

    @Test(arguments: [0, 125, 126, 0xFFFF, 0x10000])
    func framesRoundTripWithEveryLengthEncoding(length: Int) throws {
        let frame = WebSocketProtocol.Frame(.text, (0..<length).map { UInt8($0 % 251) })
        for mask: [UInt8]? in [nil, [1, 2, 3, 250]] {
            var buffer = WebSocketProtocol.encode(frame, mask: mask)
            let headerLength = (length < 126 ? 2 : length <= 0xFFFF ? 4 : 10) + (mask == nil ? 0 : 4)
            #expect(buffer.count == headerLength + length)
            #expect(try WebSocketProtocol.takeFrame(from: &buffer, maxPayload: 1 << 20) == frame)
            #expect(buffer.isEmpty)
        }
    }

    @Test func maskedPayloadIsNotSentInTheClear() {
        let bytes = WebSocketProtocol.encode(WebSocketProtocol.Frame(.text, Array("hello".utf8)), mask: [1, 2, 3, 4])
        #expect(bytes[0] == 0x81)
        #expect(bytes[1] == 0x80 | 5)
        #expect(Array(bytes[2..<6]) == [1, 2, 3, 4])
        #expect(Array(bytes[6...]) == [0x69, 0x67, 0x6F, 0x68, 0x6E])
    }

    @Test func incompleteFrameIsLeftInTheBuffer() throws {
        let frame = WebSocketProtocol.Frame(isFinal: false, .text, Array(repeating: 7, count: 300))
        let bytes = WebSocketProtocol.encode(frame, mask: nil)
        for cut in [1, 3, bytes.count - 1] {
            var buffer = Array(bytes.prefix(cut))
            #expect(try WebSocketProtocol.takeFrame(from: &buffer, maxPayload: 1 << 20) == nil)
            #expect(buffer.count == cut)
        }
        var two = bytes + WebSocketProtocol.encode(WebSocketProtocol.Frame(.ping), mask: nil)
        #expect(try WebSocketProtocol.takeFrame(from: &two, maxPayload: 1 << 20) == frame)
        #expect(try WebSocketProtocol.takeFrame(from: &two, maxPayload: 1 << 20) == WebSocketProtocol.Frame(.ping))
    }

    @Test func reservedBitsAndOversizedFramesAreRefused() {
        var reserved: [UInt8] = [0xC1, 0]
        #expect(throws: WebSocketError.protocolViolation("reserved bits set")) {
            try WebSocketProtocol.takeFrame(from: &reserved, maxPayload: 10)
        }
        var long = WebSocketProtocol.encode(WebSocketProtocol.Frame(.text, Array(repeating: 0, count: 11)), mask: nil)
        #expect(throws: WebSocketError.protocolViolation("frame longer than 10 bytes")) {
            try WebSocketProtocol.takeFrame(from: &long, maxPayload: 10)
        }
    }

    @Test func closePayloadHasTheCodeThenTheReason() {
        #expect(WebSocketProtocol.closePayload(code: 1000) == [0x03, 0xE8])
        #expect(WebSocketProtocol.closePayload(code: 1008, reason: "x") == [0x03, 0xF0, 0x78])
    }
}

/// `RexSocketConnector` and `WebSocketConnection` against real Unix sockets served by `WebSocketServer`.
struct RexSocketConnectorTests {
    private static func connect(_ server: WebSocketServer, timeout: Duration = .seconds(5)) throws -> any RexConnection
    {
        try RexSocketConnector(path: server.path).connect(until: .now + timeout)
    }

    @Test func sendsHelloAndMatchesResponsesToRequests() throws {
        let server = try WebSocketServer { message in
            if message.contains(#""type":"hello""#) { return [WebSocketServer.welcome] }
            // Both requests are in before anything is answered; the answers come in reverse order, around an event,
            // a ping and a message of a type added later.
            guard message.contains(#""id":"2""#) else { return [] }
            return [
                WebSocketServer.text(#"{"type":"event","seq":1,"payload":{"type":"session_created","payload":{}}}"#),
                WebSocketProtocol.Frame(.ping, [9]),
                WebSocketServer.response("2", #"{"blocks":[]}"#),
                WebSocketServer.text(#"{"type":"news"}"#),
                WebSocketServer.response("1", #"{"sessions":[]}"#),
            ]
        }
        let connection = try Self.connect(server)
        let answers = try connection.call([.attachAll, .blocks(of: "session:1")], until: .now + .seconds(5))
        connection.close()

        #expect(
            answers.map { String(decoding: $0, as: UTF8.self) } == [
                #"{"type":"response","id":"1","seq":0,"payload":{"sessions":[]}}"#,
                #"{"type":"response","id":"2","seq":0,"payload":{"blocks":[]}}"#,
            ])
        try waitUntil { server.messages.last == "<close>" }
        let messages = server.messages
        #expect(messages.count == 4)
        #expect(
            messages[0].hasPrefix(#"{"type":"hello","api_revision":14,"client":{"kind":"other","platform":"macos","#))
        #expect(messages[0].contains(#""name":"Buddr""#))
        #expect(
            messages[1]
                == #"{"type":"request","id":"1","method":"session.attach_all","payload":{"event_scope":"session"}}"#)
        #expect(
            messages[2]
                == #"{"type":"request","id":"2","method":"session.list_blocks","payload":{"session_id":"session:1"}}"#)
        #expect(server.pongs == [[9]])
    }

    @Test func fragmentedMessagesAreJoined() throws {
        let server = try WebSocketServer { message in
            if message.contains(#""type":"hello""#) {
                let welcome = WebSocketServer.welcome.payload
                return [
                    WebSocketProtocol.Frame(isFinal: false, .text, Array(welcome.prefix(10))),
                    WebSocketProtocol.Frame(.pong),
                    WebSocketProtocol.Frame(.continuation, Array(welcome.dropFirst(10))),
                ]
            }
            return [WebSocketServer.response("1", #"{"hosts":[]}"#)]
        }
        let connection = try Self.connect(server)
        defer { connection.close() }

        #expect(try connection.call([.hosts], until: .now + .seconds(5)).count == 1)
    }

    @Test func missingSocketMeansNotRunning() {
        let path = LineServer.temporaryPath()
        #expect(throws: RexError.notRunning(socketPath: path)) {
            try RexSocketConnector(path: path).connect(until: .now + .seconds(5))
        }
    }

    @Test func refusedUpgradeFails() throws {
        let server = try WebSocketServer(upgrade: .raw("HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n"))
        #expect(throws: RexError.connectionFailed(reason: "WebSocket handshake failed: HTTP/1.1 403 Forbidden")) {
            try Self.connect(server)
        }
    }

    @Test func connectionClosedDuringTheUpgradeFails() throws {
        let server = try WebSocketServer(upgrade: .raw("HTTP/1.1 101"))
        #expect(throws: RexError.connectionFailed(reason: "WebSocket handshake failed: connection closed")) {
            try Self.connect(server)
        }
    }

    @Test func serverThatClosesInsteadOfWelcomingFails() throws {
        let server = try WebSocketServer { _ in
            [
                WebSocketProtocol.Frame(
                    .close, WebSocketProtocol.closePayload(code: 1008, reason: "no common API revision"))
            ]
        }
        #expect(throws: RexError.connectionFailed(reason: "closed the connection (1008: no common API revision)")) {
            try Self.connect(server)
        }
    }

    @Test func somethingElseThanAWelcomeFails() throws {
        let server = try WebSocketServer { _ in [WebSocketServer.text(#"{"type":"response","id":"1"}"#)] }
        #expect(throws: RexError.connectionFailed(reason: #"expected a welcome, got {"type":"response","id":"1"}"#)) {
            try Self.connect(server)
        }
    }

    @Test func connectionDroppedWithoutAnAnswerFails() throws {
        let server = try WebSocketServer { message in message.contains("hello") ? [WebSocketServer.welcome] : nil }
        let connection = try Self.connect(server)
        #expect(throws: RexError.connectionFailed(reason: "closed the connection")) {
            try connection.call([.hosts], until: .now + .seconds(5))
        }
    }

    @Test func silentServerTimesOut() throws {
        let server = try WebSocketServer(upgrade: .silence)
        let start = ContinuousClock.now
        #expect(throws: RexError.timedOut) {
            try Self.connect(server, timeout: .milliseconds(300))
        }
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test func cancellationStopsWaiting() async throws {
        let server = try WebSocketServer(upgrade: .silence)
        let task = Task { _ = try Self.connect(server, timeout: .seconds(30)) }
        let start = ContinuousClock.now
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    /// Polls `condition` for up to two seconds: the server runs on its own thread.
    private func waitUntil(_ condition: () -> Bool) throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            guard ContinuousClock.now < deadline else { throw CancellationError() }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
}
