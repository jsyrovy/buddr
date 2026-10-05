import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    let snapshots = SnapshotStore()
    let hiding = SheepHiding()
    #if DEBUG
        let debug = DebugControls()
    #endif

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
        #if DEBUG
            let debug = debug
        #endif
        let applyStatus: @MainActor @Sendable () -> Void = {
            var status = snapshots.snapshot?.status ?? .unknown
            #if DEBUG
                status = debug.statusOverride ?? status
            #endif
            animation.setStatus(status)
            hiding.setStatus(status)
        }
        #if DEBUG
            debug.animation = animation
            debug.escape = escape
            debug.onStatusOverrideChange = applyStatus
        #endif
        var previous = HerdrSnapshot.empty
        let herdrMonitor = HerdrMonitor { snapshot in
            snapshots.snapshot = snapshot
            applyStatus()
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
