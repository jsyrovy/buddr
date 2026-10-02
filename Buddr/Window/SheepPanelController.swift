import AppKit
import SwiftUI

/// Owns the sheep panel: creates it with the SwiftUI content and places it on screen.
@MainActor
final class SheepPanelController {
    static let defaultScale = 6
    /// Distance of the panel from the screen edges in its default position.
    private static let margin: CGFloat = 24

    private let panel: SheepPanel

    init(scale: Int = defaultScale) {
        let size = CGSize(
            width: SheepSprites.canvasWidth * scale, height: SheepSprites.canvasHeight * scale)
        panel = SheepPanel(contentRect: NSRect(origin: .zero, size: size))
        let hostingView = NSHostingView(rootView: SheepView(scale: scale))
        hostingView.frame = NSRect(origin: .zero, size: size)
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
