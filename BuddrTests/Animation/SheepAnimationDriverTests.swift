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

    // MARK: Scripted clips

    private static let script = SheepSprites.Escape.startle

    private static func mirrored(_ frame: AnimationFrame) -> SpriteFrame {
        frame.sprite.mirrored(canvasWidth: SheepSprites.canvasWidth)
    }

    @Test func playShowsTheClipOnceAndHoldsItsLastFrame() async {
        let animator = SheepAnimator(status: .working, seed: 7)
        let driver = driver(animator)
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        driver.start()
        _ = await sleeps.next()

        let finished = Flag()
        let playing = Task {
            await driver.play(Self.script, mirrored: true)
            finished.set()
        }
        // The script starts right away, each frame with its full duration.
        for frame in Self.script.frames {
            #expect(await sleeps.next() == frame.duration)
            #expect(driver.sprite == Self.mirrored(frame))
            #expect(!finished.isSet)
            sleeper.wake()
        }
        await playing.value
        // The last frame stays until the script ends.
        #expect(await sleeps.next() == Self.script.frames.last?.duration)
        #expect(driver.sprite == Self.mirrored(Self.script.frames.last!))

        // The state machine continues where it stopped.
        driver.endScript()
        #expect(await sleeps.next() == animator.frame.duration)
        #expect(driver.sprite == animator.frame.sprite)
        await driver.stop()
    }

    @Test func loopRepeatsTheClipUntilTheScriptEnds() async {
        let driver = driver(SheepAnimator(status: .working, seed: 7))
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        driver.start()
        _ = await sleeps.next()

        driver.loop(Self.script)
        for frame in Self.script.frames + Self.script.frames {
            #expect(await sleeps.next() == frame.duration)
            #expect(driver.sprite == frame.sprite)
            sleeper.wake()
        }
        await driver.stop()
    }

    @Test func waitForCycleEndReturnsAfterTheLastFrameOfTheClip() async {
        let animator = SheepAnimator(status: .working, seed: 7)
        let frames = animator.clip.frames.count
        let driver = driver(animator)
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        driver.start()
        _ = await sleeps.next()

        let ended = Flag()
        let waiting = Task {
            await driver.waitForCycleEnd()
            ended.set()
        }
        for _ in 0..<frames - 1 {
            sleeper.wake()
            _ = await sleeps.next()
            #expect(!ended.isSet)
        }
        sleeper.wake()
        await waiting.value
        #expect(ended.isSet)
        await driver.stop()
    }

    @Test func stopEndsAPendingPlay() async {
        let driver = driver(SheepAnimator(status: .working, seed: 7))
        var sleeps = sleeper.sleeps.makeAsyncIterator()
        driver.start()
        _ = await sleeps.next()

        let playing = Task { await driver.play(Self.script) }
        _ = await sleeps.next()
        await driver.stop()
        await playing.value
    }
}

@MainActor
private final class Flag {
    private(set) var isSet = false

    func set() {
        isSet = true
    }
}
