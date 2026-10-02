import os

@testable import Buddr

/// Answers polls with the given snapshots in order; after the last one, a poll runs until it is cancelled.
final class ScriptedFetch: Sendable {
    /// Reports every poll when it starts.
    let calls: AsyncStream<Void>
    private let callsContinuation: AsyncStream<Void>.Continuation
    private let state: OSAllocatedUnfairLock<(count: Int, snapshots: [HerdrSnapshot])>

    init(_ snapshots: [HerdrSnapshot]) {
        (calls, callsContinuation) = AsyncStream.makeStream(of: Void.self)
        state = OSAllocatedUnfairLock(initialState: (0, snapshots))
    }

    var count: Int {
        state.withLock { $0.count }
    }

    func callAsFunction() async -> HerdrSnapshot {
        let snapshot = state.withLock { state in
            state.count += 1
            return state.snapshots.isEmpty ? nil : state.snapshots.removeFirst()
        }
        callsContinuation.yield()
        if let snapshot {
            return snapshot
        }
        // Never fires, so this returns once the poll is cancelled. The result differs from every scripted
        // snapshot, so delivering it would show up in the updates.
        await OneShotSignal().wait()
        return .empty
    }
}

/// Collects the snapshots a poller or monitor delivers.
@MainActor
final class SnapshotRecorder {
    var snapshots: [HerdrSnapshot] = []
}
