@testable import Buddr

extension Buddy {
    /// A buddy whose every clip is `frames` frames of an empty picture, 100 ms each: easy to tell from the sheep.
    static func stub(name: String = "Stub", frames: Int = 2) -> Buddy {
        let clip = AnimationClip(
            Array(
                repeating: AnimationFrame(sprite: SpriteFrame(layers: []), duration: .milliseconds(100)), count: frames)
        )
        return Buddy(
            id: .sheep, name: name,
            clips: Clips(
                idleRest: clip, idleBlink: clip, idleLook: clip, sleeping: clip, working: clip, blocked: clip,
                doneJump: clip, doneHold: clip, unknown: clip, idleStill: clip, sleepingStill: clip,
                workingStill: clip, blockedStill: clip, doneStill: clip, unknownStill: clip),
            escape: Escape(startle: clip, yawn: clip, turn: clip, run: clip, walk: clip, arrive: clip),
            petted: clip, grids: [], palette: [:])
    }
}
