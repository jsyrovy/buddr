import Testing

@testable import Buddr

struct SheepClipsTests {
    /// Every clip by name: the state machine's, the escape's and the petting reaction.
    private static let clips: [String: AnimationClip] = Dictionary(
        uniqueKeysWithValues: SheepClipID.allCases.map { ("\($0)", SheepSprites.clip($0)) } + [
            ("escapeStartle", SheepSprites.Escape.startle), ("escapeTurn", SheepSprites.Escape.turn),
            ("escapeRun", SheepSprites.Escape.run), ("escapeArrive", SheepSprites.Escape.arrive),
            ("escapeYawn", SheepSprites.Escape.yawn), ("escapeWalk", SheepSprites.Escape.walk),
            ("petted", SheepSprites.petted),
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
        let expected = [.unknown, .unknownStill].contains(id) ? SheepSprites.unknownOpacity : 1
        #expect(clip.frames.allSatisfy { $0.sprite.opacity == expected })
    }

    /// A still pose is one short frame (a state change waits for it to end) made of the pictures of its state's clip,
    /// so it shows the same sign ("!", "zzz", …).
    @Test(arguments: [
        (SheepClipID.idleStill, SheepClipID.idleRest), (.sleepingStill, .sleeping), (.workingStill, .working),
        (.blockedStill, .blocked), (.doneStill, .doneHold), (.unknownStill, .unknown),
    ])
    func stillPosesAreOneShortFrameOfTheirClipsPictures(still: SheepClipID, animated: SheepClipID) {
        let frames = SheepSprites.clip(still).frames
        #expect(frames.count == 1)
        #expect(frames.allSatisfy { $0.duration <= .milliseconds(500) })
        let clipLayers = Set(SheepSprites.clip(animated).frames.flatMap(\.sprite.layers))
        #expect(Set(frames.flatMap(\.sprite.layers)).isSubset(of: clipLayers))
    }
}
