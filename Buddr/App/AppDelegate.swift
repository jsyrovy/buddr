import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    let snapshots = SnapshotStore()
    let hiding = SheepHiding()

    private var animation: SheepAnimationDriver?
    private var panelController: SheepPanelController?
    private var herdrMonitor: HerdrMonitor?
    private var fullscreenMonitor: FullscreenMonitor?
    private var escape: SheepEscape?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let animation = SheepAnimationDriver()
        animation.start()
        self.animation = animation

        let panelController = SheepPanelController(animation: animation)
        let hiding = hiding
        panelController.onClick = {
            animation.interject(SheepSprites.petted)
            hiding.restartCountdown()
        }
        panelController.show()
        self.panelController = panelController

        let escape = SheepEscape(panel: panelController, animation: animation)
        self.escape = escape

        let fullscreenMonitor = FullscreenMonitor(sheepFrame: { escape.homeFrame }) { fullscreen in
            escape.setAway(fullscreen, for: .fullscreen)
        }
        fullscreenMonitor.start()
        self.fullscreenMonitor = fullscreenMonitor

        hiding.onChange = { hidden in
            escape.setAway(hidden, for: .hiding)
        }

        let preferences = preferences
        let snapshots = snapshots
        var previous = HerdrSnapshot.empty
        let herdrMonitor = HerdrMonitor { snapshot in
            snapshots.snapshot = snapshot
            animation.setStatus(snapshot.status)
            hiding.setStatus(snapshot.status)
            if snapshot.hasAgentsNewlyNeedingAttention(since: previous) {
                animation.replay()
            }
            previous = snapshot
        }
        let applyPreferences: @MainActor @Sendable () -> Void = {
            herdrMonitor.setEnabled(preferences.watchesRemoteMachines, .machines)
            animation.setAnimation(preferences.animationMode, for: .seconds(preferences.animationSeconds))
            hiding.setMode(preferences.hideMode, after: .seconds(preferences.hideMinutes * 60))
        }
        applyPreferences()
        preferences.onChange = applyPreferences
        herdrMonitor.start()
        self.herdrMonitor = herdrMonitor
    }

    func agentListOpened() {
        herdrMonitor?.refresh()
    }
}
