import AppKit
import SwiftUI

/// Owns the sheep panel: creates it with the SwiftUI content and places it on screen.
@MainActor
final class SheepPanelController {
    static let defaultScale = 6
    /// Distance of the panel from the screen edges in its default position.
    private static let margin: CGFloat = 24

    private let panel: SheepPanel

    init(animation: SheepAnimationDriver, scale: Int = defaultScale) {
        let hostingView = NSHostingView(rootView: SheepView(animation: animation, scale: scale))
        // The content has a fixed size; don't let SwiftUI updates re-evaluate the window size on every frame.
        hostingView.sizingOptions = []
        panel = SheepPanel(contentRect: NSRect(origin: .zero, size: hostingView.fittingSize))
        panel.contentView = hostingView
    }

    func show() {
        moveToDefaultPosition()
        panel.orderFrontRegardless()
    }

    /// Bottom-right corner of the main screen, above the Dock.
    private func moveToDefaultPosition() {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        let origin = NSPoint(
            x: visibleFrame.maxX - panel.frame.width - Self.margin, y: visibleFrame.minY + Self.margin)
        panel.setFrameOrigin(origin)
    }
}
