import Foundation
import os

@testable import Buddr

/// A `CoreTransport` that answers every request with the same canned answer or error.
struct FakeCoreTransport: CoreTransport {
    var answer: Result<Data, CoreError>
    private let requests = OSAllocatedUnfairLock<[String]>(initialState: [])

    init(_ answer: Result<Data, CoreError>) {
        self.answer = answer
    }

    static func fixture(_ name: String) throws -> FakeCoreTransport {
        FakeCoreTransport(.success(try Fixture.data(name)))
    }

    /// Every request line, in call order.
    var recordedLines: [String] {
        requests.withLock { $0 }
    }

    func request(_ line: Data, timeout: Duration) async throws -> Data {
        requests.withLock { $0.append(String(decoding: line, as: UTF8.self)) }
        return try answer.get()
    }
}
