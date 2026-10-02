import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: SheepPanelController?
    private var poller: HerdrPoller?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The test bundle is hosted by the app; keep the host inert while tests run.
        guard !RuntimeEnvironment.isRunningTests else { return }

        let panelController = SheepPanelController()
        panelController.show()
        self.panelController = panelController

        // The snapshot drives the sheep once animations are wired up; for now the poller only logs.
        let poller = HerdrPoller { _ in }
        poller.start()
        self.poller = poller
    }
}
