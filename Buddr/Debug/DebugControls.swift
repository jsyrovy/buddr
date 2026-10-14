#if DEBUG
    import Observation

    /// What the debug section of the menu bar list (`DebugSection`) does: plays any clip by hand, sends the sheep away
    /// and back, overrides the status the sheep shows and the text of its name plate. Debug builds only.
    @MainActor
    @Observable
    final class DebugControls {
        /// Shown by the sheep (and used for hiding) instead of the aggregated herdr status while set.
        var statusOverride: AgentStatus? {
            didSet { onChange?() }
        }
        /// The name plate shows a long sample instead of its text, to check shortening and the screen edges.
        var longNamePlate = false {
            didSet { onChange?() }
        }
        /// Clips are repeated until `stopClip()` instead of played once.
        var loops = false
        /// Clips are played mirrored, facing right.
        var mirrored = false

        /// Called when the status override or the name plate sample changes.
        @ObservationIgnored var onChange: (@MainActor () -> Void)?
        @ObservationIgnored var animation: SheepAnimationDriver?
        @ObservationIgnored var escape: SheepEscape?

        /// The plate shown for `status` instead of `plate`: the long sample, or a placeholder when the status is
        /// overridden and no agent is in it, so the plate can be checked without agents.
        func namePlate(_ plate: NamePlate?, for status: AgentStatus) -> NamePlate? {
            guard status.needsAttention, plate != nil || statusOverride == status else { return plate }
            if longNamePlate {
                return NamePlate(
                    prefix: "Devbox · a-workspace-with-a-long-name",
                    title: "Refactor the escape route so that the sheep always finds its way back home", more: 3)
            }
            return plate ?? NamePlate(prefix: "debug", title: status.rawValue, more: 0)
        }

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
