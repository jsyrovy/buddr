import AppKit

extension NSImage {
    /// A template image of the sprite's opaque pixels, e.g. for the menu bar: only the shape counts, the system picks
    /// the color. Every pixel is a `pointsPerPixel` square drawn without antialiasing, so it stays sharp when the
    /// square is a whole number of device pixels.
    static func template(from sprite: PixelSprite, pointsPerPixel: Double) -> NSImage {
        let size = NSSize(width: Double(sprite.width) * pointsPerPixel, height: Double(sprite.height) * pointsPerPixel)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current else { return false }
            context.shouldAntialias = false
            NSColor.black.setFill()
            for y in 0..<sprite.height {
                for x in 0..<sprite.width where sprite.color(x: x, y: y) != nil {
                    NSRect(
                        x: Double(x) * pointsPerPixel, y: Double(y) * pointsPerPixel, width: pointsPerPixel,
                        height: pointsPerPixel
                    ).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
