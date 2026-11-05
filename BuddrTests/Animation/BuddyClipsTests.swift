import Testing

@testable import Buddr

/// What every buddy has to do (`Buddy`), checked for each of them.
struct BuddyClipsTests {
    private static let clipNames = BuddyID.sheep.buddy.allClips.map(\.name)

    private static func clip(_ name: String, of id: BuddyID) throws -> AnimationClip {
        try #require(id.buddy.allClips.first { $0.name == name }).clip
    }

    @Test(arguments: BuddyID.allCases)
    func clipNamesAreUnique(id: BuddyID) {
        let names = id.buddy.allClips.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test(arguments: BuddyID.allCases)
    func buddyKnowsItsID(id: BuddyID) {
        #expect(id.buddy.id == id)
        #expect(!id.name.isEmpty)
    }

    @Test(arguments: BuddyID.allCases, clipNames)
    func everyClipHasFramesWithPositiveDurations(id: BuddyID, name: String) throws {
        let clip = try Self.clip(name, of: id)
        #expect(!clip.frames.isEmpty)
        #expect(clip.frames.allSatisfy { $0.duration > .zero })
    }

    /// Clips play to their end before a state change shows, so they must stay short.
    @Test(arguments: BuddyID.allCases, clipNames)
    func clipCyclesAreShort(id: BuddyID, name: String) throws {
        #expect(try Self.clip(name, of: id).cycleDuration <= .milliseconds(1_600))
    }

    @Test(arguments: BuddyID.allCases, clipNames)
    func everyFrameFitsOnTheCanvas(id: BuddyID, name: String) throws {
        for frame in try Self.clip(name, of: id).frames {
            for layer in frame.sprite.layers {
                #expect(layer.x >= 0 && layer.x + layer.sprite.width <= BuddyCanvas.width)
                #expect(layer.y >= 0 && layer.y + layer.sprite.height <= BuddyCanvas.height)
            }
        }
    }

    @Test(arguments: BuddyID.allCases, ClipID.allCases)
    func onlyTheUnknownStateIsDimmed(id: BuddyID, clipID: ClipID) {
        let expected = [.unknown, .unknownStill].contains(clipID) ? BuddyCanvas.unknownOpacity : 1
        #expect(id.buddy.clips[clipID].frames.allSatisfy { $0.sprite.opacity == expected })
    }

    /// A still pose is one short frame (a state change waits for it to end) made of the pictures of its state's clip,
    /// so it shows the same sign ("!", "zzz", …).
    @Test(
        arguments: BuddyID.allCases,
        [
            (ClipID.idleStill, ClipID.idleRest), (.sleepingStill, .sleeping), (.workingStill, .working),
            (.blockedStill, .blocked), (.doneStill, .doneHold), (.unknownStill, .unknown),
        ])
    func stillPosesAreOneShortFrameOfTheirClipsPictures(id: BuddyID, clips: (still: ClipID, animated: ClipID)) {
        let frames = id.buddy.clips[clips.still].frames
        #expect(frames.count == 1)
        #expect(frames.allSatisfy { $0.duration <= .milliseconds(500) })
        let clipLayers = Set(id.buddy.clips[clips.animated].frames.flatMap(\.sprite.layers))
        #expect(Set(frames.flatMap(\.sprite.layers)).isSubset(of: clipLayers))
    }

    /// The name plate is centered under the canvas, right below it: a buddy at rest stands on the bottom row, in the
    /// middle.
    @Test(arguments: BuddyID.allCases)
    func buddyAtRestStandsCenteredOnTheBottomRow(id: BuddyID) throws {
        let frame = try #require(id.buddy.clips[.idleStill].frames.first).sprite
        let opaque = frame.layers.flatMap { layer in
            (0..<layer.sprite.height).flatMap { y in
                (0..<layer.sprite.width).compactMap { x in
                    layer.sprite.color(x: x, y: y) == nil ? nil : (x: layer.x + x, y: layer.y + y)
                }
            }
        }
        let left = try #require(opaque.map(\.x).min())
        let right = try #require(opaque.map(\.x).max())
        #expect(opaque.map(\.y).max() == BuddyCanvas.height - 1)
        #expect(abs(left - (BuddyCanvas.width - 1 - right)) <= 1)
    }
}
