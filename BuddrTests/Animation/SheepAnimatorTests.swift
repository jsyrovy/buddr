import Testing

@testable import Buddr

struct SheepAnimatorTests {
    /// Moves to the last frame of the current clip.
    private func advanceToLastFrame(_ animator: inout SheepAnimator) {
        while animator.frameIndex + 1 < animator.clip.frames.count {
            animator.advance()
        }
    }

    /// Plays the current clip to its end, so the next clip starts.
    private func finishCycle(_ animator: inout SheepAnimator) {
        advanceToLastFrame(&animator)
        animator.advance()
    }

    @Test(arguments: [
        (AgentStatus.working, SheepClipID.working),
        (.blocked, .blocked),
        (.done, .doneJump),
        (.unknown, .unknown),
    ])
    func startsWithTheClipOfItsStatus(status: AgentStatus, clip: SheepClipID) {
        let animator = SheepAnimator(status: status, seed: 1)
        #expect(animator.clipID == clip)
        #expect(animator.frameIndex == 0)
    }

    @Test func idleStartsWithACalmClip() {
        for seed in 0..<50 {
            let animator = SheepAnimator(status: .idle, seed: UInt64(seed))
            #expect([.idleRest, .idleBlink, .idleLook].contains(animator.clipID))
        }
    }

    @Test func statusChangeWaitsForTheRunningCycleToFinish() throws {
        var animator = SheepAnimator(status: .working, seed: 1)
        try #require(animator.clip.frames.count > 2)
        animator.advance()
        animator.setStatus(.blocked)

        // The working clip keeps playing until its last frame has been shown.
        #expect(animator.clipID == .working)
        #expect(animator.frameIndex == 1)
        advanceToLastFrame(&animator)
        #expect(animator.clipID == .working)

        animator.advance()
        #expect(animator.clipID == .blocked)
        #expect(animator.frameIndex == 0)
    }

    @Test func statusChangeOnTheLastFrameSwitchesOnTheNextAdvance() {
        var animator = SheepAnimator(status: .blocked, seed: 1)
        advanceToLastFrame(&animator)
        animator.setStatus(.done)
        #expect(animator.clipID == .blocked)
        animator.advance()
        #expect(animator.clipID == .doneJump)
    }

    @Test func onlyTheLatestStatusCountsWhenItChangesSeveralTimesInOneCycle() {
        var animator = SheepAnimator(status: .working, seed: 1)
        animator.setStatus(.blocked)
        animator.setStatus(.idle)
        animator.setStatus(.unknown)
        finishCycle(&animator)
        #expect(animator.clipID == .unknown)
    }

    @Test(arguments: [AgentStatus.working, .blocked, .unknown])
    func loopingStatusesRepeatTheirClip(status: AgentStatus) {
        var animator = SheepAnimator(status: status, seed: 1)
        let clip = animator.clipID
        for _ in 0..<5 {
            finishCycle(&animator)
            #expect(animator.clipID == clip)
        }
    }

    @Test func doneJumpsFirstAndThenMostlyHolds() {
        var animator = SheepAnimator(status: .working, seed: 1)
        animator.setStatus(.done)
        var clips: [SheepClipID] = []
        for _ in 0..<(2 * SheepAnimator.doneJumpEvery) {
            finishCycle(&animator)
            clips.append(animator.clipID)
        }
        let expectedCycle = [SheepClipID.doneJump] + Array(repeating: .doneHold, count: SheepAnimator.doneJumpEvery - 1)
        #expect(clips == expectedCycle + expectedCycle)
    }

    @Test func idleFallsAsleepAfterTheConfiguredTime() {
        var animator = SheepAnimator(status: .idle, sleepAfter: .seconds(10), seed: 7)
        var elapsed = Duration.zero
        while animator.clipID != .sleeping && elapsed < .seconds(20) {
            elapsed += animator.frame.duration
            animator.advance()
        }
        // It falls asleep at the first clip boundary after 10 s.
        #expect(animator.clipID == .sleeping)
        #expect(elapsed >= .seconds(10) && elapsed < .seconds(12))
        // Once asleep, it keeps sleeping while idle.
        for _ in 0..<5 {
            finishCycle(&animator)
            #expect(animator.clipID == .sleeping)
        }
    }

    @Test func idleVariesBetweenRestBlinkAndLook() {
        var animator = SheepAnimator(status: .idle, sleepAfter: .seconds(3_600), seed: 42)
        var seen: Set<SheepClipID> = [animator.clipID]
        for _ in 0..<200 {
            finishCycle(&animator)
            seen.insert(animator.clipID)
        }
        #expect(seen == [.idleRest, .idleBlink, .idleLook])
    }

    @Test func leavingIdleResetsTheSleepTimer() {
        var animator = SheepAnimator(status: .idle, sleepAfter: .seconds(10), seed: 3)
        var elapsed = Duration.zero
        while elapsed < .seconds(8) {
            elapsed += animator.frame.duration
            animator.advance()
        }
        animator.setStatus(.working)
        finishCycle(&animator)
        #expect(animator.clipID == .working)

        animator.setStatus(.idle)
        finishCycle(&animator)
        #expect(animator.clipID != .sleeping)
    }

    @Test func wakesUpWhenAgentsStartWorking() {
        var animator = SheepAnimator(status: .idle, sleepAfter: .zero, seed: 1)
        finishCycle(&animator)
        #expect(animator.clipID == .sleeping)
        animator.setStatus(.working)
        #expect(animator.clipID == .sleeping)
        finishCycle(&animator)
        #expect(animator.clipID == .working)
    }

    @Test func sameSeedGivesTheSameSequence() {
        func sequence(seed: UInt64) -> [SheepClipID] {
            var animator = SheepAnimator(status: .idle, sleepAfter: .seconds(3_600), seed: seed)
            return (0..<30).map { _ in
                finishCycle(&animator)
                return animator.clipID
            }
        }
        #expect(sequence(seed: 9) == sequence(seed: 9))
    }
}
