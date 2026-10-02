import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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

        let herdrMonitor = HerdrMonitor { snapshot in
            animation.setStatus(snapshot.status)
        }
        herdrMonitor.start()
        self.herdrMonitor = herdrMonitor
    }
}
