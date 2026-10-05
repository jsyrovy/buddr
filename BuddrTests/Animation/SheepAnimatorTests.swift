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

    /// Advances frame by frame until at least `duration` has been played; returns the time played.
    @discardableResult
    private func play(_ duration: Duration, _ animator: inout SheepAnimator) -> Duration {
        var elapsed = Duration.zero
        while elapsed < duration {
            elapsed += animator.frame.duration
            animator.advance()
        }
        return elapsed
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
        play(.seconds(8), &animator)
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

    private static let stillPoses: Set<SheepClipID> = [
        .idleStill, .sleepingStill, .workingStill, .blockedStill, .doneStill, .unknownStill,
    ]

    @Test(arguments: [
        (AgentStatus.idle, SheepClipID.idleStill), (.working, .workingStill), (.blocked, .blockedStill),
        (.done, .doneStill), (.unknown, .unknownStill),
    ])
    func withoutAnimationTheStatusShowsAStillPose(status: AgentStatus, still: SheepClipID) {
        var animator = SheepAnimator(status: .working, mode: .off, sleepAfter: .seconds(3_600), seed: 1)
        animator.setStatus(status)
        for _ in 0..<5 {
            finishCycle(&animator)
            #expect(animator.clipID == still)
        }
    }

    @Test func withoutAnimationIdleFallsAsleepAsAStillPose() {
        var animator = SheepAnimator(status: .idle, mode: .off, sleepAfter: .seconds(10), seed: 1)
        #expect(animator.clipID == .idleStill)
        let elapsed = play(.seconds(10), &animator)
        #expect(animator.clipID == .sleepingStill)
        #expect(elapsed < .seconds(11))
    }

    @Test func onChangeAnimatesForTheGivenTimeAfterAStatusChange() {
        var animator = SheepAnimator(status: .working, mode: .onChange, animatesFor: .seconds(3), seed: 1)
        let elapsed = play(.seconds(3), &animator)
        // The clip that was playing at 3 s finished first.
        #expect(animator.clipID == .workingStill)
        #expect(animator.frameIndex == 0)
        #expect(elapsed < .seconds(3) + SheepSprites.clip(.working).cycleDuration)

        animator.setStatus(.blocked)
        finishCycle(&animator)
        #expect(animator.clipID == .blocked)
        play(.seconds(2), &animator)
        #expect(animator.clipID == .blocked)
        play(.seconds(2), &animator)
        #expect(animator.clipID == .blockedStill)
    }

    @Test func replayAnimatesTheSameStatusAgainFromItsStart() {
        var animator = SheepAnimator(status: .done, mode: .onChange, animatesFor: .seconds(2), seed: 1)
        play(.seconds(3), &animator)
        #expect(animator.clipID == .doneStill)

        animator.replay()
        #expect(animator.clipID == .doneStill)
        finishCycle(&animator)
        #expect(animator.clipID == .doneJump)
        play(.seconds(3), &animator)
        #expect(animator.clipID == .doneStill)
    }

    @Test func replayJumpsAgainWhileAlwaysAnimated() {
        var animator = SheepAnimator(status: .done, seed: 1)
        finishCycle(&animator)
        #expect(animator.clipID == .doneHold)
        animator.replay()
        finishCycle(&animator)
        #expect(animator.clipID == .doneJump)
    }

    @Test func changingTheAnimationTakesEffectWhenTheClipEnds() throws {
        var animator = SheepAnimator(status: .working, seed: 1)
        try #require(animator.clip.frames.count > 1)
        animator.advance()
        animator.setAnimation(.off, for: .seconds(10))
        #expect(animator.clipID == .working)
        advanceToLastFrame(&animator)
        animator.advance()
        #expect(animator.clipID == .workingStill)

        animator.setAnimation(.always, for: .seconds(10))
        finishCycle(&animator)
        #expect(animator.clipID == .working)
    }

    @Test func onChangeCountsTheTimeSinceTheLastChange() {
        var animator = SheepAnimator(status: .working, seed: 1)
        play(.seconds(5), &animator)

        // Already animated for longer since the last change: still right away.
        animator.setAnimation(.onChange, for: .seconds(3))
        finishCycle(&animator)
        #expect(animator.clipID == .workingStill)

        // A longer time lets it move again for the rest of it.
        animator.setAnimation(.onChange, for: .seconds(8))
        finishCycle(&animator)
        #expect(animator.clipID == .working)
        play(.seconds(3), &animator)
        #expect(animator.clipID == .workingStill)
    }

    @Test(arguments: [AgentStatus.idle, .working, .blocked, .done, .unknown])
    func alwaysAnimatedNeverShowsAStillPose(status: AgentStatus) {
        var animator = SheepAnimator(status: status, sleepAfter: .seconds(5), seed: 1)
        for _ in 0..<50 {
            #expect(!Self.stillPoses.contains(animator.clipID))
            finishCycle(&animator)
        }
    }
}
