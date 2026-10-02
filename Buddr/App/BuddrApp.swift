import SwiftUI

/// Entry point. The unit test bundle is hosted by the app; under tests an empty app runs instead of Buddr, so no
/// panel, polling or menu bar item is started and the real app needs no test guards.
@main
enum BuddrMain {
    @MainActor
    static func main() {
        if RuntimeEnvironment.isRunningTests {
            TestHostApp.main()
        } else {
            BuddrApp.main()
        }
    }
}

struct BuddrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Buddr", systemImage: "pawprint.fill") {
            Button("Quit Buddr") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

private struct TestHostApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }
}
