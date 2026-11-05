import Testing

@testable import Buddr

struct SheepClipsTests {
    /// Names are unique: building the dictionary traps otherwise.
    private static let clips = Dictionary(uniqueKeysWithValues: SheepSprites.allClips.map { ($0.name, $0.clip) })
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
                #expect(layer.x >= 0 && layer.x + layer.sprite.width <= BuddyCanvas.width)
                #expect(layer.y >= 0 && layer.y + layer.sprite.height <= BuddyCanvas.height)
            }
        }
    }

    @Test(arguments: ClipID.allCases)
    func onlyTheUnknownStateIsDimmed(id: ClipID) {
        let clip = SheepSprites.clip(id)
        let expected = [.unknown, .unknownStill].contains(id) ? BuddyCanvas.unknownOpacity : 1
        #expect(clip.frames.allSatisfy { $0.sprite.opacity == expected })
    }

    /// A still pose is one short frame (a state change waits for it to end) made of the pictures of its state's clip,
    /// so it shows the same sign ("!", "zzz", …).
    @Test(arguments: [
        (ClipID.idleStill, ClipID.idleRest), (.sleepingStill, .sleeping), (.workingStill, .working),
        (.blockedStill, .blocked), (.doneStill, .doneHold), (.unknownStill, .unknown),
    ])
    func stillPosesAreOneShortFrameOfTheirClipsPictures(still: ClipID, animated: ClipID) {
        let frames = SheepSprites.clip(still).frames
        #expect(frames.count == 1)
        #expect(frames.allSatisfy { $0.duration <= .milliseconds(500) })
        let clipLayers = Set(SheepSprites.clip(animated).frames.flatMap(\.sprite.layers))
        #expect(Set(frames.flatMap(\.sprite.layers)).isSubset(of: clipLayers))
    }
}
