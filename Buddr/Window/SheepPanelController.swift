import AppKit
import SwiftUI

/// Owns the sheep panel: creates it with the SwiftUI content and places it on screen.
@MainActor
final class SheepPanelController {
    static let defaultScale = 6
    /// Distance of the panel from the screen edges in its default position.
    private static let margin: CGFloat = 24

    /// Points per sprite pixel.
    let scale: Int
    /// Called when the sheep is clicked rather than dragged.
    var onClick: (() -> Void)?
    private let panel: SheepPanel

    init(animation: SheepAnimationDriver, scale: Int = defaultScale) {
        self.scale = scale
        // The size is set explicitly: `NSHostingView.fittingSize` is still zero here, and placing a zero-sized panel
        // in the corner pushed the real panel off screen.
        panel = SheepPanel(contentRect: NSRect(origin: .zero, size: SheepView.size(scale: scale)))
        let hostingView = NSHostingView(rootView: SheepView(animation: animation, scale: scale))
        // The content has a fixed size; don't let SwiftUI updates re-evaluate the window size on every frame.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onDragEnd = { [weak self] in
            self?.keepOnScreen()
        }
        panel.onClick = { [weak self] in
            self?.onClick?()
        }
    }

    func show() {
        moveToDefaultPosition()
        panel.orderFrontRegardless()
    }

    /// Hides the panel (for example while a fullscreen window covers its display) or shows it again in place.
    func setHidden(_ hidden: Bool) {
        if hidden {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    var frame: NSRect {
        panel.frame
    }

    func setOrigin(_ origin: NSPoint) {
        panel.setFrameOrigin(origin)
    }

    /// Whether the sheep can be dragged and clicked; off while it escapes, so it can't be grabbed on the run.
    func setInteractive(_ interactive: Bool) {
        panel.ignoresMouseEvents = !interactive
    }

    /// The screen for a panel at `frame`: the one showing most of it, or the nearest one.
    func screen(for frame: NSRect) -> NSScreen? {
        let screens = NSScreen.screens
        return ScreenGeometry.screen(for: frame, in: screens.map(\.frame)).map { screens[$0] }
    }

    /// Where a panel at `frame` may sit: moved into the visible area of its screen (outside the menu bar and the
    /// Dock). `nil` without screens.
    func onScreenOrigin(for frame: NSRect) -> NSPoint? {
        screen(for: frame).map { ScreenGeometry.clampedOrigin(of: frame, into: $0.visibleFrame) }
    }

    /// Moves the panel back on screen after a drag, so it can't be dragged out of sight by accident.
    private func keepOnScreen() {
        if let origin = onScreenOrigin(for: panel.frame) {
            panel.setFrameOrigin(origin)
        }
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
