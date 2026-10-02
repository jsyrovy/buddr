import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var animation: SheepAnimationDriver?
    private var panelController: SheepPanelController?
    private var poller: HerdrPoller?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The test bundle is hosted by the app; keep the host inert while tests run.
        guard !RuntimeEnvironment.isRunningTests else { return }

        let animation = SheepAnimationDriver()
        animation.start()
        self.animation = animation

        let panelController = SheepPanelController(animation: animation)
        panelController.show()
        self.panelController = panelController

        let poller = HerdrPoller { snapshot in
            animation.setStatus(snapshot.status)
        }
        poller.start()
        self.poller = poller
    }
}
