import AppKit

/// Makes the sheep run off the screen while a fullscreen window covers its display, and come back afterwards.
///
/// Running away: the current clip plays to its end, a startled hop, turning to the nearer edge, running until the
/// panel is off the screen, then the panel is hidden. Coming back: the panel appears past the same edge and the sheep
/// runs back home. Each way is played to its end; a change of mind meanwhile is handled right after it.
@MainActor
final class SheepEscape {
    private static let frameInterval: Duration = .milliseconds(16)

    private let panel: SheepPanelController
    private let animation: SheepAnimationDriver
    private var wantsAway = false
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

    func setAway(_ away: Bool) {
        wantsAway = away
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

    private func runAway() async {
        panel.setInteractive(false)
        await animation.waitForCycleEnd()
        let frame = panel.frame
        guard wantsAway, let screen = panel.screen(for: frame) else {
            // Fullscreen ended before the clip did, or there is no screen at all.
            panel.setInteractive(true)
            wantsAway = false
            return
        }
        home = frame.origin
        let route = EscapeRoute(panelFrame: frame, screenFrame: screen.frame)
        await animation.play(SheepSprites.Escape.startle)
        let towardsRight = route.edge == .right
        if towardsRight {
            await animation.play(SheepSprites.Escape.turn, mirrored: true)
        }
        animation.loop(SheepSprites.Escape.run, mirrored: towardsRight)
        await move(from: route.home, to: route.away, duration: route.duration, easeOut: false)
        panel.setHidden(true)
        animation.endScript()
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
        let route = EscapeRoute(panelFrame: NSRect(origin: target, size: homeFrame.size), screenFrame: screen.frame)
        panel.setOrigin(route.away)
        panel.setHidden(false)
        animation.loop(SheepSprites.Escape.run, mirrored: route.edge == .left)
        await move(from: route.away, to: route.home, duration: route.duration, easeOut: true)
        await animation.play(SheepSprites.Escape.arrive)
        animation.endScript()
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
