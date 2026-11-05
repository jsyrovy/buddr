import CoreGraphics

/// Size and place of the name plate under the buddy panel, in screen coordinates (AppKit, y up).
enum NamePlateLayout {
    /// Points per plate pixel: smaller pixels than the buddy's, 2 at the default scale 6.
    static func plateScale(buddyScale: Int) -> Int {
        max(1, buddyScale / NamePlateSprite.pixelDivisor)
    }

    /// Room kept free below the buddy panel, so the buddy doesn't have to move when a plate appears: the plate and
    /// the gap above it.
    static func reservedHeight(buddyScale: Int) -> CGFloat {
        CGFloat((NamePlateSprite.height + NamePlateSprite.gap) * plateScale(buddyScale: buddyScale))
    }

    /// The plate centered under the buddy (whose body is centered on the canvas), the plate gap below its feet, and
    /// moved horizontally into `visibleFrame`; a plate wider than that is aligned to its left edge.
    static func frame(plateSize: CGSize, buddyFrame: CGRect, visibleFrame: CGRect, plateScale: Int) -> CGRect {
        let gap = CGFloat(NamePlateSprite.gap * plateScale)
        let centered = CGRect(
            origin: CGPoint(x: buddyFrame.midX - plateSize.width / 2, y: buddyFrame.minY - gap - plateSize.height),
            size: plateSize)
        let x = ScreenGeometry.clampedOrigin(of: centered, into: visibleFrame).x
        return CGRect(origin: CGPoint(x: x, y: centered.minY), size: plateSize)
    }
}
