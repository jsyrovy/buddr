import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences: Preferences
    /// Created before the menu bar list, which names the buddy.
    let animation: BuddyAnimationDriver
    let snapshots = SnapshotStore()
    let hiding = BuddyHiding()
    let turns: BuddyTurns
    #if DEBUG
        let debug = DebugControls()
    #endif

    private var panelController: BuddyPanelController?
    private var herdrMonitor: HerdrMonitor?
    private var fullscreenMonitor: FullscreenMonitor?
    private var escape: BuddyEscape?

    override init() {
        let preferences = Preferences()
        self.preferences = preferences
        let buddy = preferences.buddyAtLaunch
        animation = BuddyAnimationDriver(animator: BuddyAnimator(buddy: buddy.buddy))
        turns = BuddyTurns(current: buddy)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let animation = animation
        animation.start()

        let panelController = BuddyPanelController(animation: animation)
        let hiding = hiding
        panelController.onClick = {
            animation.interject(animation.buddy.petted)
            hiding.restartCountdown()
        }
        panelController.show()
        self.panelController = panelController

        let escape = BuddyEscape(panel: panelController, animation: animation)
        self.escape = escape

        let fullscreenMonitor = FullscreenMonitor(buddyFrame: { escape.homeFrame }) { fullscreen in
            escape.setAway(fullscreen, for: .fullscreen)
        }
        fullscreenMonitor.start()
        self.fullscreenMonitor = fullscreenMonitor

        hiding.onChange = { hidden in
            escape.setAway(hidden, for: .hiding)
        }

        let preferences = preferences
        let turns = turns
        turns.onChange = { buddy in
            preferences.shownBuddy = buddy
            escape.switchBuddy(to: buddy.buddy)
        }
        let snapshots = snapshots
        #if DEBUG
            let debug = debug
        #endif
        var attention = AttentionTracker()
        let applyStatus: @MainActor () -> Void = {
            let snapshot = snapshots.snapshot ?? .empty
            var status = snapshot.status
            #if DEBUG
                status = debug.statusOverride ?? status
            #endif
            animation.setStatus(status)
            hiding.setStatus(status)
            turns.setStatus(status)
            var plate = attention.update(with: snapshot, status: status)
            #if DEBUG
                plate = debug.namePlate(plate, for: status)
            #endif
            panelController.setNamePlate(plate)
            if attention.hasNewArrivals {
                // Even when the aggregated status stays the same.
                animation.replay()
            }
        }
        #if DEBUG
            debug.animation = animation
            debug.escape = escape
            debug.onChange = applyStatus
        #endif
        let herdrMonitor = HerdrMonitor { snapshot in
            snapshots.snapshot = snapshot
            applyStatus()
        }
        let applyPreferences: @MainActor @Sendable () -> Void = {
            herdrMonitor.configure(
                backends: preferences.backendChoice.backends,
                watchesRemoteMachines: preferences.watchesRemoteMachines)
            animation.setAnimation(preferences.animationMode, for: .seconds(preferences.animationSeconds))
            hiding.setMode(preferences.hideMode, after: .seconds(preferences.hideMinutes * 60))
            turns.setChoice(preferences.buddyChoice, every: .seconds(preferences.buddyTurnMinutes * 60))
            panelController.setNamePlateFields(preferences.shownNamePlateFields)
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
