import AppKit
import os

/// Watches whether the display with the sheep is covered by a fullscreen window and reports changes on the main actor.
/// `sheepFrame` is where the sheep belongs, also while it is away.
///
/// Checks run on every Space change (a native fullscreen app gets its own Space) and on display changes, repeated
/// shortly after since the window list can lag behind the notification, and once a second as a fallback for
/// borderless fullscreen windows that don't change the Space. `FullscreenDebounce` decides when fullscreen ends.
@MainActor
final class FullscreenMonitor {
    private static let logger = Logger(subsystem: "cz.jsyrovy.buddr", category: "fullscreen")
    private static let recheckDelay: Duration = .milliseconds(250)
    private static let interval: Duration = .seconds(1)

    private let sheepFrame: @MainActor () -> NSRect
    private let onChange: @MainActor (Bool) -> Void
    private var observers: [NSObjectProtocol] = []
    private var pollTask: Task<Void, Never>?
    private var recheckTask: Task<Void, Never>?
    private var confirmTask: Task<Void, Never>?
    private var debounce = FullscreenDebounce()

    init(sheepFrame: @escaping @MainActor () -> NSRect, onChange: @escaping @MainActor (Bool) -> Void) {
        self.sheepFrame = sheepFrame
        self.onChange = onChange
    }

    func start() {
        guard pollTask == nil else { return }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification)
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                // The tolerance lets the system coalesce the wakeup with others.
                try? await Task.sleep(for: Self.interval, tolerance: .milliseconds(250))
                self?.check()
            }
        }
        check()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkWithRecheck()
            }
        }
        observers.append(observer)
    }

    private func checkWithRecheck() {
        check()
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            try? await Task.sleep(for: Self.recheckDelay)
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    private func check() {
        let window = fullscreenWindow()
        confirmTask?.cancel()
        switch debounce.observe(window != nil, at: .now) {
        case .unchanged:
            break
        case .confirm(let delay):
            confirmTask = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.check()
            }
        case .changed(let isFullscreen):
            if let window {
                Self.logger.notice(
                    "fullscreen on: \(window.ownerName, privacy: .public) (pid \(window.ownerPID)), layer \(window.layer)"
                )
            } else {
                Self.logger.notice("fullscreen off")
            }
            onChange(isFullscreen)
        }
    }

    private func fullscreenWindow() -> WindowInfo? {
        let displays = NSScreen.screens.compactMap(Self.displayInfo)
        guard let display = FullscreenDetector.display(containing: sheepFrame(), in: displays) else { return nil }
        let list =
            CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return FullscreenDetector.fullscreenWindow(
            in: FullscreenDetector.windows(from: list), display: display,
            excludingPID: ProcessInfo.processInfo.processIdentifier)
    }

    private static func displayInfo(_ screen: NSScreen) -> DisplayInfo? {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return DisplayInfo(frame: screen.frame, bounds: CGDisplayBounds(id), topInset: screen.safeAreaInsets.top)
    }
}
