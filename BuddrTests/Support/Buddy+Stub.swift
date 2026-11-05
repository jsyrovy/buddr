@testable import Buddr

extension Buddy {
    /// A buddy whose every clip is `frames` frames of an empty picture, 100 ms each: easy to tell from the sheep.
    static func stub(frames: Int = 2) -> Buddy {
        let clip = AnimationClip(
            Array(
                repeating: AnimationFrame(sprite: SpriteFrame(layers: []), duration: .milliseconds(100)), count: frames)
        )
        return Buddy(
            id: .sheep, clips: ClipSet { _ in clip }, escape: ClipSet { _ in clip }, petted: clip)
    }
}
