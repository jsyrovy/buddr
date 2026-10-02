import Testing

@testable import Buddr

@MainActor
struct SheepAnimationDriverTests {
    private let sleeper = ManualSleeper()

    private func driver(_ animator: SheepAnimator) -> SheepAnimationDriver {
        SheepAnimationDriver(animator: animator, sleep: sleeper.sleep(for:))
    }

    @Test func playsTheAnimatorFrameByFrame() async {
        // A copy of the animator with the same seed plays the expected frames.
        var expected = SheepAnimator(status: .working, seed: 7)
        let driver = driver(expected)
        var sleeps = sleeper.sleeps.makeAsyncIterator()

        driver.start()
        for step in 0..<90 {
            // Every frame is shown for its own duration.
            #expect(await sleeps.next() == expected.frame.duration)
            #expect(driver.sprite == expected.frame.sprite)
            if step == 30 {
                driver.setStatus(.blocked)
                expected.setStatus(.blocked)
            } else if step == 60 {
                driver.setStatus(.done)
                expected.setStatus(.done)
            }
            sleeper.wake()
            expected.advance()
        }
        await driver.stop()
    }

    @Test func stopFreezesThePicture() async throws {
        let animator = SheepAnimator(status: .working, seed: 7)
        var next = animator
        next.advance()
        try #require(next.frame.sprite != animator.frame.sprite)
        let driver = driver(animator)
        var sleeps = sleeper.sleeps.makeAsyncIterator()

        driver.start()
        _ = await sleeps.next()
        await driver.stop()

        #expect(driver.sprite == animator.frame.sprite)
    }
}
