import AppKit

/// Borderless, transparent, non-activating floating panel that hosts the sheep.
///
/// It never becomes key or main, so clicking it does not steal focus from the active app. A mouse down on the sheep
/// drags the panel.
final class SheepPanel: NSPanel {
    /// Called once the mouse button is released after a drag.
    var onDragEnd: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        // Dragging is handled here rather than with `isMovableByWindowBackground`, so it does not depend on how the
        // SwiftUI hosting view handles mouse events.
        if event.type == .leftMouseDown {
            performDrag(with: event)
            notifyWhenMouseIsUp()
            return
        }
        super.sendEvent(event)
    }

    /// The window server moves the window during the drag; the end is noticed by the released button.
    private func notifyWhenMouseIsUp() {
        Task { [weak self] in
            while NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: .milliseconds(50))
            }
            self?.onDragEnd?()
        }
    }
}
