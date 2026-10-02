import Testing

@testable import Buddr

struct SheepClipsTests {
    /// Every clip by name: the state machine's and the escape's.
    private static let clips: [String: AnimationClip] = Dictionary(
        uniqueKeysWithValues: SheepClipID.allCases.map { ("\($0)", SheepSprites.clip($0)) } + [
            ("escapeStartle", SheepSprites.Escape.startle), ("escapeTurn", SheepSprites.Escape.turn),
            ("escapeRun", SheepSprites.Escape.run), ("escapeArrive", SheepSprites.Escape.arrive),
        ])
    private static let clipNames = clips.keys.sorted()

    @Test(arguments: clipNames)
    func everyClipHasFramesWithPositiveDurations(name: String) throws {
        let clip = try #require(Self.clips[name])
        #expect(!clip.frames.isEmpty)
        #expect(clip.frames.allSatisfy { $0.duration > .zero })
    }

    /// Clips play to their end before a state change shows, so they must stay short.
    @Test(arguments: clipNames)
    func clipCyclesAreShort(name: String) throws {
        let clip = try #require(Self.clips[name])
        #expect(clip.cycleDuration <= .milliseconds(1_600))
    }

    @Test(arguments: clipNames)
    func everyFrameFitsOnTheCanvas(name: String) throws {
        let clip = try #require(Self.clips[name])
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
