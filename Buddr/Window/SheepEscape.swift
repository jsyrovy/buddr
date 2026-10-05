import AppKit

/// Makes the sheep run off the screen while it should be away – a fullscreen window covers its display, or it hides
/// (`SheepHiding`) – and come back once there is no reason left.
///
/// Running away: the current clip plays to its end, a startled hop (or a yawn when the sheep only hides), turning to the
/// nearer edge, running (walking) until the panel is off the screen, then the panel is hidden. Coming back: the panel appears past the same edge and the sheep
/// runs back home. Each way is played to its end; a change of mind meanwhile is handled right after it. Without
/// animation (`AnimationMode.off`) or without any screen, the panel is just hidden and shown again.
@MainActor
final class SheepEscape {
    private static let frameInterval: Duration = .milliseconds(16)

    private let panel: SheepPanelController
    private let animation: SheepAnimationDriver
    /// Why the sheep should be away; it is away while there is any.
    private var reasons: Set<Reason> = []
    private var isAway = false
    private var task: Task<Void, Never>?
    /// Panel origin to come back to, kept from the start of an escape until the sheep is back.
    private var home: CGPoint?

    init(panel: SheepPanelController, animation: SheepAnimationDriver) {
        self.panel = panel
        self.animation = animation
    }

    /// Where the sheep belongs: its home while it is away or on the way, otherwise where the panel is.
    var homeFrame: NSRect {
        guard let home else { return panel.frame }
        return NSRect(origin: home, size: panel.frame.size)
    }

    enum Reason: Hashable {
        case fullscreen
        case hiding
        #if DEBUG
            /// Sent away by hand from the debug section of the menu bar list.
            case debug(startled: Bool)
        #endif

        /// Whether the sheep leaves startled; it wanders off bored when no reason is.
        var startles: Bool {
            switch self {
            case .fullscreen: true
            case .hiding: false
            #if DEBUG
                case .debug(let startled): startled
            #endif
            }
        }
    }

    func setAway(_ away: Bool, for reason: Reason) {
        if away {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }
        guard task == nil else { return }
        task = Task {
            while wantsAway != isAway {
                if wantsAway {
                    await runAway()
                } else {
                    await comeBack()
                }
            }
            task = nil
        }
    }

    private var wantsAway: Bool {
        !reasons.isEmpty
    }

    private func runAway() async {
        panel.setInteractive(false)
        guard runs else {
            hide()
            return
        }
        await animation.waitForCycleEnd()
        guard wantsAway else {
            // The reason went away before the clip ended.
            panel.setInteractive(true)
            return
        }
        let frame = panel.frame
        guard let screen = panel.screen(for: frame) else {
            hide()
            return
        }
        // Hiding alone is no hurry: the sheep yawns and wanders off. A fullscreen window startles it.
        let wandersOff = !reasons.contains(where: \.startles)
        if wandersOff {
            await animation.play(SheepSprites.Escape.yawn)
            guard wantsAway else {
                // Something happened during the yawn.
                animation.endScript()
                panel.setInteractive(true)
                return
            }
        } else {
            await animation.play(SheepSprites.Escape.startle)
        }
        home = frame.origin
        let route = EscapeRoute(panelFrame: frame, screenFrame: screen.frame, pace: wandersOff ? .walk : .run)
        let towardsRight = route.edge == .right
        if towardsRight {
            await animation.play(SheepSprites.Escape.turn, mirrored: true)
        }
        animation.loop(wandersOff ? SheepSprites.Escape.walk : SheepSprites.Escape.run, mirrored: towardsRight)
        await move(from: route.home, to: route.away, duration: route.duration, easeOut: false)
        panel.setHidden(true)
        animation.endScript()
        isAway = true
    }

    /// Hides the panel right away, without running.
    private func hide() {
        home = panel.frame.origin
        panel.setHidden(true)
        isAway = true
    }

    private func comeBack() async {
        let homeFrame = homeFrame
        defer {
            home = nil
            panel.setInteractive(true)
            isAway = false
        }
        // The screen may have gone meanwhile; the sheep then comes back to the nearest one.
        guard let screen = panel.screen(for: homeFrame), let target = panel.onScreenOrigin(for: homeFrame) else {
            // No screen at all: just show the panel where it was.
            panel.setHidden(false)
            return
        }
        guard runs else {
            panel.setOrigin(target)
            panel.setHidden(false)
            return
        }
        let route = EscapeRoute(panelFrame: NSRect(origin: target, size: homeFrame.size), screenFrame: screen.frame)
        panel.setOrigin(route.away)
        panel.setHidden(false)
        animation.loop(SheepSprites.Escape.run, mirrored: route.edge == .left)
        await move(from: route.away, to: route.home, duration: route.duration, easeOut: true)
        await animation.play(SheepSprites.Escape.arrive)
        animation.endScript()
    }

    /// The sheep runs off the screen and back only while it is animated at all; read at the start of each way.
    private var runs: Bool {
        animation.animationMode != .off
    }

    /// Moves the panel horizontally in steps of one sprite pixel, checked ~60 times a second.
    private func move(from: CGPoint, to: CGPoint, duration: Duration, easeOut: Bool) async {
        let start = ContinuousClock.now
        var lastX: CGFloat?
        while true {
            let time = (ContinuousClock.now - start) / duration
            let x = EscapeRoute.x(from: from.x, to: to.x, time: time, step: CGFloat(panel.scale), easeOut: easeOut)
            if x != lastX {
                panel.setOrigin(CGPoint(x: x, y: from.y))
                lastX = x
            }
            if time >= 1 { return }
            try? await Task.sleep(for: Self.frameInterval)
        }
    }
}
