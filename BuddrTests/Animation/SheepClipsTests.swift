import Testing

@testable import Buddr

struct SheepClipsTests {
    @Test(arguments: SheepClipID.allCases)
    func everyClipHasFramesWithPositiveDurations(id: SheepClipID) throws {
        let clip = try #require(SheepSprites.clips[id])
        #expect(!clip.frames.isEmpty)
        #expect(clip.frames.allSatisfy { $0.duration > .zero })
    }

    /// Clips play to their end before a state change shows, so they must stay short.
    @Test(arguments: SheepClipID.allCases)
    func clipCyclesAreShort(id: SheepClipID) throws {
        let clip = try #require(SheepSprites.clips[id])
        #expect(clip.cycleDuration <= .milliseconds(1_600))
    }

    @Test(arguments: SheepClipID.allCases)
    func everyFrameFitsOnTheCanvas(id: SheepClipID) throws {
        let clip = try #require(SheepSprites.clips[id])
        for frame in clip.frames {
            for layer in frame.sprite.layers {
                #expect(layer.x >= 0 && layer.x + layer.sprite.width <= SheepSprites.canvasWidth)
                #expect(layer.y >= 0 && layer.y + layer.sprite.height <= SheepSprites.canvasHeight)
            }
        }
    }

    @Test(arguments: SheepClipID.allCases)
    func onlyTheUnknownStateIsDimmed(id: SheepClipID) throws {
        let clip = try #require(SheepSprites.clips[id])
        let expected = id == .unknown ? SheepSprites.unknownOpacity : 1
        #expect(clip.frames.allSatisfy { $0.sprite.opacity == expected })
    }
}
