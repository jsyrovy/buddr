/// The plate under the buddy naming the agent it reports (`NamePlate.Label`): light text in `PixelFont` on a dark plate
/// with cut corners. Drawn with its own, smaller pixels (`NamePlateLayout.plateScale(buddyScale:)`). It belongs to the
/// app, not to a buddy: every buddy gets the same plate.
enum NamePlateSprite {
    /// A plate pixel is this many times smaller than a buddy pixel (rounded down, at least one point).
    static let pixelDivisor = 3
    static let fill = PixelColor(red: 0x2A, green: 0x24, blue: 0x30)
    static let text = PixelColor(red: 0xF7, green: 0xF4, blue: 0xEC)
    /// Plate pixels between the text and the left and right edges.
    static let paddingX = 3
    /// Plate pixels above the text and below its descender rows, so text without descenders looks centered.
    static let paddingTop = 3
    static let paddingBottom = 1
    /// Plate pixels between the buddy's feet and the plate.
    static let gap = 2
    /// Longest text in plate pixels; longer ones are shortened (`text(for:maxWidth:)`).
    static let maxTextWidth = 100
    static let height = paddingTop + PixelFont.height + paddingBottom

    /// The text of `label`, at most `maxWidth` pixels wide: the title is shortened with `…`, keeping the machine
    /// and workspace before it and the `+N` after it. When even those don't fit, the whole text is cut at the end.
    static func text(for label: NamePlate.Label, maxWidth: Int = maxTextWidth) -> String {
        let shortenedTitle =
            label.title.isEmpty
            ? nil
            : PixelFont.shortened(label.title, between: label.lead, and: label.suffix, maxWidth: maxWidth)
        return shortenedTitle ?? PixelFont.shortened(label.text, maxWidth: maxWidth) ?? ""
    }

    static func sprite(for plate: NamePlate.Label) -> PixelSprite {
        let label = PixelFont.sprite(for: text(for: plate), color: text)
        let width = label.width + 2 * paddingX
        let pixels = (0..<height).flatMap { y in
            (0..<width).map { x -> PixelColor? in
                let isCorner = (x == 0 || x == width - 1) && (y == 0 || y == height - 1)
                if isCorner { return nil }
                return label.color(x: x - paddingX, y: y - paddingTop) ?? fill
            }
        }
        return PixelSprite(width: width, height: height, pixels: pixels)
    }
}
