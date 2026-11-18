import Foundation
import os

@testable import Buddr

/// A `HerdrCoreTransport` that answers every request with the same canned answer or error.
struct FakeHerdrCoreTransport: HerdrCoreTransport {
    var answer: Result<Data, HerdrCoreError>
    private let requests = OSAllocatedUnfairLock<[String]>(initialState: [])

    init(_ answer: Result<Data, HerdrCoreError>) {
        self.answer = answer
    }

    static func fixture(_ name: String) throws -> FakeHerdrCoreTransport {
        FakeHerdrCoreTransport(.success(try Fixture.data(name)))
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
