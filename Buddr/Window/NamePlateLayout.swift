import CoreGraphics

/// Size and place of the name plate under the sheep panel, in screen coordinates (AppKit, y up).
enum NamePlateLayout {
    /// Points per plate pixel: smaller pixels than the sheep's, 2 at the default scale 6.
    static func plateScale(sheepScale: Int) -> Int {
        max(1, sheepScale / SheepSprites.Plate.pixelDivisor)
    }

    /// Room kept free below the sheep panel, so the sheep doesn't have to move when a plate appears: the plate and
    /// the gap above it.
    static func reservedHeight(sheepScale: Int) -> CGFloat {
        CGFloat((SheepSprites.Plate.height + SheepSprites.Plate.gap) * plateScale(sheepScale: sheepScale))
    }

    /// The plate centered under the sheep (whose body is centered on the canvas), the plate gap below its feet, and
    /// moved horizontally into `visibleFrame`; a plate wider than that is aligned to its left edge.
    static func frame(plateSize: CGSize, sheepFrame: CGRect, visibleFrame: CGRect, plateScale: Int) -> CGRect {
        let gap = CGFloat(SheepSprites.Plate.gap * plateScale)
        let centered = CGRect(
            origin: CGPoint(x: sheepFrame.midX - plateSize.width / 2, y: sheepFrame.minY - gap - plateSize.height),
            size: plateSize)
        let x = ScreenGeometry.clampedOrigin(of: centered, into: visibleFrame).x
        return CGRect(origin: CGPoint(x: x, y: centered.minY), size: plateSize)
    }
}
