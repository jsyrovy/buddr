import SwiftUI

@main
struct BuddrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Buddr", systemImage: "pawprint.fill", isInserted: .constant(!RuntimeEnvironment.isRunningTests)) {
            Button("Quit Buddr") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
