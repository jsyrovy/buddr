import Testing

@testable import Buddr

struct SheepClipsTests {
    @Test(arguments: SheepClipID.allCases)
    func everyClipHasFramesWithPositiveDurations(id: SheepClipID) {
        let clip = SheepSprites.clip(id)
        #expect(!clip.frames.isEmpty)
        #expect(clip.frames.allSatisfy { $0.duration > .zero })
    }

    /// Clips play to their end before a state change shows, so they must stay short.
    @Test(arguments: SheepClipID.allCases)
    func clipCyclesAreShort(id: SheepClipID) {
        let clip = SheepSprites.clip(id)
        #expect(clip.cycleDuration <= .milliseconds(1_600))
    }

    @Test(arguments: SheepClipID.allCases)
    func everyFrameFitsOnTheCanvas(id: SheepClipID) {
        let clip = SheepSprites.clip(id)
        for frame in clip.frames {
            for layer in frame.sprite.layers {
                #expect(layer.x >= 0 && layer.x + layer.sprite.width <= SheepSprites.canvasWidth)
                #expect(layer.y >= 0 && layer.y + layer.sprite.height <= SheepSprites.canvasHeight)
            }
        }
    }

    @Test(arguments: SheepClipID.allCases)
    func onlyTheUnknownStateIsDimmed(id: SheepClipID) {
        let clip = SheepSprites.clip(id)
        let expected = id == .unknown ? SheepSprites.unknownOpacity : 1
        #expect(clip.frames.allSatisfy { $0.sprite.opacity == expected })
    }
}
