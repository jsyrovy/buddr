import AppKit
import SwiftUI

/// The floating panel with the name plate, a child window of the sheep panel so it moves along with it. It never
/// takes the mouse: clicks go through it to whatever is below.
final class NamePlatePanel: FloatingPanel {
    private let hostingView: NSHostingView<SpriteCanvas>
    /// Points per plate pixel.
    let scale: Int

    init(scale: Int) {
        self.scale = scale
        hostingView = NSHostingView(
            rootView: SpriteCanvas(sprite: PixelSprite(width: 0, height: 0, pixels: []), scale: scale))
        // The size follows the text and is set explicitly; SwiftUI updates shouldn't resize the window.
        hostingView.sizingOptions = []
        super.init(contentRect: .zero)
        ignoresMouseEvents = true
        contentView = hostingView
    }

    /// Shows `label` and resizes the panel to fit it, keeping its origin.
    func show(_ label: NamePlate.Label) {
        let sprite = SheepSprites.Plate.sprite(for: label)
        hostingView.rootView = SpriteCanvas(sprite: sprite, scale: scale)
        let size = SpriteCanvas.size(gridWidth: sprite.width, gridHeight: sprite.height, scale: scale)
        setFrame(NSRect(origin: frame.origin, size: size), display: true)
    }
}
