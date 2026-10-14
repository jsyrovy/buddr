import AppKit
import SwiftUI

/// Borderless, transparent panel with the name plate, a child window of the sheep panel so it moves along with it.
/// It floats like the sheep but never takes the mouse: clicks go through it to whatever is below.
final class NamePlatePanel: NSPanel {
    private let hostingView: NSHostingView<NamePlateView>
    /// Points per plate pixel.
    let scale: Int

    init(scale: Int) {
        self.scale = scale
        let empty = NamePlateView(sprite: PixelSprite(width: 0, height: 0, pixels: []), scale: scale)
        hostingView = NSHostingView(rootView: empty)
        // The size follows the text and is set explicitly; SwiftUI updates shouldn't resize the window.
        hostingView.sizingOptions = []
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        ignoresMouseEvents = true
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Shows `text` and resizes the panel to fit it, keeping its origin.
    func setText(_ text: String) {
        let sprite = SheepSprites.Plate.sprite(for: text)
        hostingView.rootView = NamePlateView(sprite: sprite, scale: scale)
        let size = SpriteCanvas.size(gridWidth: sprite.width, gridHeight: sprite.height, scale: scale)
        setFrame(NSRect(origin: frame.origin, size: size), display: true)
    }
}
