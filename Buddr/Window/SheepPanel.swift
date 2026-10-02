import AppKit

/// Borderless, transparent, non-activating floating panel that hosts the sheep.
///
/// It never becomes key or main, so clicking it does not steal focus from the active app. A mouse down on the sheep
/// drags the panel.
final class SheepPanel: NSPanel {
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
            return
        }
        super.sendEvent(event)
    }
}
