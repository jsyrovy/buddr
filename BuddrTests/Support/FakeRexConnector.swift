import Foundation
import os

@testable import Buddr

/// A `RexConnector` whose connections answer every request from a script: a payload (JSON) or an error code per
/// request; anything else fails with `internal`. Records every round of requests (an empty one sends nothing, so it is
/// not recorded) and whether connections were closed.
struct FakeRexConnector: RexConnector {
    enum Answer: Sendable {
        case payload(String)
        case error(String)
    }

    private let failure: RexError?
    private let answers: [RexRequest: Answer]
    private let log = OSAllocatedUnfairLock(initialState: (rounds: [[RexRequest]](), opened: 0, closed: 0))

    init(_ answers: [RexRequest: Answer] = [:]) {
        self.answers = answers
        failure = nil
    }

    /// A connector that can't connect.
    init(failing failure: RexError) {
        answers = [:]
        self.failure = failure
    }

    /// Every round of requests, in call order.
    var rounds: [[RexRequest]] { log.withLock { $0.rounds } }
    var openConnections: Int { log.withLock { $0.opened - $0.closed } }

    func connect(until deadline: ContinuousClock.Instant) throws -> any RexConnection {
        if let failure { throw failure }
        log.withLock { $0.opened += 1 }
        return Connection(connector: self)
    }

    private final class Connection: RexConnection {
        let connector: FakeRexConnector

        init(connector: FakeRexConnector) {
            self.connector = connector
        }

        func call(_ requests: [RexRequest], until deadline: ContinuousClock.Instant) throws -> [Data] {
            if !requests.isEmpty {
                connector.log.withLock { $0.rounds.append(requests) }
            }
            return requests.map { request in
                let body =
                    switch connector.answers[request] ?? .error("internal") {
                    case .payload(let payload): #""payload":\#(payload)"#
                    case .error(let code): #""error":{"code":"\#(code)","message":"\#(code) message","status":500}"#
                    }
                return Data(#"{"type":"response","id":"1","seq":0,\#(body)}"#.utf8)
            }
        }

        func close() {
            connector.log.withLock { $0.closed += 1 }
        }
    }
}
