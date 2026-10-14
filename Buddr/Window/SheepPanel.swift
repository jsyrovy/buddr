import AppKit

/// The floating panel that hosts the sheep.
///
/// A mouse down on the sheep drags the panel; when the button is released before the panel has moved, it was a click.
/// Clicking it does not steal focus from the active app (`FloatingPanel`).
final class SheepPanel: FloatingPanel {
    /// How far the panel may move during a click, in points: a click with a slightly shaking hand moves it a little.
    static let clickTolerance: CGFloat = 2

    /// Called once the mouse button is released after a drag, also after a click.
    var onDragEnd: (() -> Void)?
    /// Called after `onDragEnd` when the panel has not moved (more than `clickTolerance`) between press and release.
    var onClick: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        // Dragging is handled here rather than with `isMovableByWindowBackground`, so it does not depend on how the
        // SwiftUI hosting view handles mouse events.
        if event.type == .leftMouseDown {
            let origin = frame.origin
            performDrag(with: event)
            notifyWhenMouseIsUp(dragStart: origin)
            return
        }
        super.sendEvent(event)
    }

    /// The window server moves the window during the drag; the end is noticed by the released button.
    private func notifyWhenMouseIsUp(dragStart: NSPoint) {
        Task { [weak self] in
            while NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard let self else { return }
            let wasClick = Self.isClick(dragStart: dragStart, dragEnd: frame.origin)
            onDragEnd?()
            if wasClick {
                onClick?()
            }
        }
    }

    /// Whether a drag that moved the panel from `dragStart` to `dragEnd` was a click.
    static func isClick(dragStart: NSPoint, dragEnd: NSPoint) -> Bool {
        abs(dragEnd.x - dragStart.x) <= clickTolerance && abs(dragEnd.y - dragStart.y) <= clickTolerance
    }
}
