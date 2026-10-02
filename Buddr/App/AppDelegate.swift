import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var animation: SheepAnimationDriver?
    private var panelController: SheepPanelController?
    private var poller: HerdrPoller?
    private var fullscreenMonitor: FullscreenMonitor?
    private var escape: SheepEscape?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let animation = SheepAnimationDriver()
        animation.start()
        self.animation = animation

        let panelController = SheepPanelController(animation: animation)
        panelController.onClick = {
            animation.interject(SheepSprites.petted)
        }
        panelController.show()
        self.panelController = panelController

        let escape = SheepEscape(panel: panelController, animation: animation)
        self.escape = escape

        let fullscreenMonitor = FullscreenMonitor(sheepFrame: { escape.homeFrame }) { fullscreen in
            escape.setAway(fullscreen)
        }
        fullscreenMonitor.start()
        self.fullscreenMonitor = fullscreenMonitor

        let poller = HerdrPoller { snapshot in
            animation.setStatus(snapshot.status)
        }
        poller.start()
        self.poller = poller
    }
}
