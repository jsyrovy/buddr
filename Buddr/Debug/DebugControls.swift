#if DEBUG
    import Observation

    /// What the debug section of the menu bar list (`DebugSection`) does: plays any clip by hand, sends the sheep away
    /// and back, and overrides the status the sheep shows. Debug builds only.
    @MainActor
    @Observable
    final class DebugControls {
        /// Shown by the sheep (and used for hiding) instead of the aggregated herdr status while set.
        var statusOverride: AgentStatus? {
            didSet { onStatusOverrideChange?() }
        }
        /// Clips are repeated until `stopClip()` instead of played once.
        var loops = false
        /// Clips are played mirrored, facing right.
        var mirrored = false

        @ObservationIgnored var onStatusOverrideChange: (@MainActor () -> Void)?
        @ObservationIgnored var animation: SheepAnimationDriver?
        @ObservationIgnored var escape: SheepEscape?

        /// Plays `clip` right away in place of whatever plays.
        func play(_ clip: AnimationClip) {
            if loops {
                animation?.loop(clip, mirrored: mirrored)
            } else {
                animation?.endScript()
                animation?.interject(clip, mirrored: mirrored)
            }
        }

        /// Hands the animation back to the state machine.
        func stopClip() {
            animation?.endScript()
        }

        /// Sends the sheep off the screen: running like from a fullscreen window, or wandering off like when it hides.
        func sendAway(startled: Bool) {
            escape?.setAway(true, for: .debug(startled: startled))
        }

        /// Brings the sheep back unless it is away for a real reason.
        func callBack() {
            escape?.setAway(false, for: .debug(startled: true))
            escape?.setAway(false, for: .debug(startled: false))
        }
    }
#endif
