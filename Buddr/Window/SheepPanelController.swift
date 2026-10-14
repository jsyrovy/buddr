import AppKit
import SwiftUI

/// Owns the sheep panel: creates it with the SwiftUI content and places it on screen, where the user left it last
/// time. Also owns the name plate under the sheep, a child window of the sheep panel; room for it is always kept
/// below the panel.
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
    private let plate: NamePlatePanel
    /// What the name plate shows; `nil` without a plate.
    private var namePlate: NamePlate?
    /// Whether the plate is hidden although it has a text, while the sheep runs away and back.
    private var isPlateSuppressed = false
    private var screenObserver: NSObjectProtocol?

    init(animation: SheepAnimationDriver, scale: Int = defaultScale) {
        self.scale = scale
        // The size is set explicitly: `NSHostingView.fittingSize` is still zero here, and placing a zero-sized panel
        // in the corner pushed the real panel off screen.
        panel = SheepPanel(contentRect: NSRect(origin: .zero, size: SheepView.size(scale: scale)))
        let hostingView = NSHostingView(rootView: SheepView(animation: animation, scale: scale))
        // The content has a fixed size; don't let SwiftUI updates re-evaluate the window size on every frame.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        plate = NamePlatePanel(scale: NamePlateLayout.plateScale(sheepScale: scale))
        panel.onDragEnd = { [weak self] in
            self?.dragEnded()
        }
        panel.onClick = { [weak self] in
            self?.onClick?()
        }
    }

    func show() {
        moveToInitialPosition()
        panel.orderFrontRegardless()
        updatePlate()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.layoutPlate()
            }
        }
    }

    /// Hides the panel (for example while a fullscreen window covers its display) or shows it again in place.
    func setHidden(_ hidden: Bool) {
        if hidden {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
        updatePlate()
    }

    var frame: NSRect {
        panel.frame
    }

    func setOrigin(_ origin: NSPoint) {
        panel.setFrameOrigin(origin)
        layoutPlate()
    }

    /// Shows `namePlate` under the sheep, or no plate for `nil`. The plate is drawn only when it changes.
    func setNamePlate(_ namePlate: NamePlate?) {
        guard namePlate != self.namePlate else { return }
        self.namePlate = namePlate
        if let namePlate {
            plate.show(namePlate)
        }
        updatePlate()
    }

    /// Hides the plate while the sheep runs away and back; it shows again (if there is one) when lifted.
    func setNamePlateSuppressed(_ suppressed: Bool) {
        isPlateSuppressed = suppressed
        updatePlate()
    }

    private var showsPlate: Bool {
        namePlate != nil && !isPlateSuppressed && panel.isVisible
    }

    /// Shows the plate as a child of the sheep panel while it should be seen, otherwise takes it away. Done explicitly
    /// rather than relying on how AppKit orders child windows with their parent.
    private func updatePlate() {
        if showsPlate {
            layoutPlate()
            if plate.parent == nil {
                panel.addChildWindow(plate, ordered: .above)
            }
            plate.orderFrontRegardless()
        } else {
            if plate.parent != nil {
                panel.removeChildWindow(plate)
            }
            plate.orderOut(nil)
        }
    }

    /// Places a visible plate under the sheep, inside the visible area of the sheep's screen. A child window moves
    /// with its parent on its own, but keeping it on screen depends on where the sheep is.
    private func layoutPlate() {
        guard showsPlate, let screen = screen(for: panel.frame) else { return }
        let frame = NamePlateLayout.frame(
            plateSize: plate.frame.size, sheepFrame: panel.frame, visibleFrame: screen.visibleFrame,
            plateScale: plate.scale)
        if frame.origin != plate.frame.origin {
            plate.setFrameOrigin(frame.origin)
        }
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
    /// Dock), with room for the name plate below it. `nil` without screens.
    func onScreenOrigin(for frame: NSRect) -> NSPoint? {
        screen(for: frame).map {
            Self.onScreenOrigin(of: frame, in: $0.visibleFrame, reservedBelow: reservedBelow)
        }
    }

    /// Room for the name plate below the panel.
    private var reservedBelow: CGFloat {
        NamePlateLayout.reservedHeight(sheepScale: scale)
    }

    /// Origin that moves a panel at `frame` into `visibleFrame`, together with `reservedBelow` points below it.
    static func onScreenOrigin(of frame: NSRect, in visibleFrame: NSRect, reservedBelow: CGFloat) -> NSPoint {
        let extended = NSRect(
            x: frame.minX, y: frame.minY - reservedBelow, width: frame.width, height: frame.height + reservedBelow)
        let origin = ScreenGeometry.clampedOrigin(of: extended, into: visibleFrame)
        return NSPoint(x: origin.x, y: origin.y + reservedBelow)
    }

    /// Moves the panel back on screen after a drag, so it can't be dragged out of sight by accident, and remembers
    /// the position for the next launch.
    private func dragEnded() {
        if let origin = onScreenOrigin(for: panel.frame) {
            setOrigin(origin)
        }
        PanelPositionStore.save(panel.frame.origin)
    }

    /// The saved position, moved onto a screen (the screens may have changed since), or the default corner.
    private func moveToInitialPosition() {
        let size = panel.frame.size
        let origin =
            PanelPositionStore.load().flatMap { onScreenOrigin(for: NSRect(origin: $0, size: size)) }
            ?? NSScreen.main.map {
                Self.defaultOrigin(panelSize: size, visibleFrame: $0.visibleFrame, reservedBelow: reservedBelow)
            }
        if let origin {
            panel.setFrameOrigin(origin)
        }
    }

    /// Bottom-right corner of the visible screen area (above the Dock), `margin` away from the edges, with
    /// `reservedBelow` points for the name plate between the panel and the bottom margin.
    static func defaultOrigin(panelSize: CGSize, visibleFrame: NSRect, reservedBelow: CGFloat) -> NSPoint {
        NSPoint(x: visibleFrame.maxX - panelSize.width - margin, y: visibleFrame.minY + margin + reservedBelow)
    }
}
