import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The test bundle is hosted by the app; keep the host inert while tests run.
        guard !RuntimeEnvironment.isRunningTests else { return }
    }
}
