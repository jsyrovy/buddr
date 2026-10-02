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
        // The size is set explicitly: `NSHostingView.fittingSize` is still zero here, and placing a zero-sized panel
        // in the corner pushed the real panel off screen.
        panel = SheepPanel(contentRect: NSRect(origin: .zero, size: SheepView.size(scale: scale)))
        let hostingView = NSHostingView(rootView: SheepView(animation: animation, scale: scale))
        // The content has a fixed size; don't let SwiftUI updates re-evaluate the window size on every frame.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    func show() {
        moveToDefaultPosition()
        panel.orderFrontRegardless()
    }

    var frame: NSRect {
        panel.frame
    }

    private func moveToDefaultPosition() {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(Self.defaultOrigin(panelSize: panel.frame.size, visibleFrame: visibleFrame))
    }

    /// Bottom-right corner of the visible screen area (above the Dock), `margin` away from the edges.
    static func defaultOrigin(panelSize: CGSize, visibleFrame: NSRect) -> NSPoint {
        NSPoint(x: visibleFrame.maxX - panelSize.width - margin, y: visibleFrame.minY + margin)
    }
}
