import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: SheepPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The test bundle is hosted by the app; keep the host inert while tests run.
        guard !RuntimeEnvironment.isRunningTests else { return }

        let panelController = SheepPanelController()
        panelController.show()
        self.panelController = panelController
    }
}
