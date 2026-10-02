import CoreGraphics

/// Placement math on screen frames, all in the same coordinate space.
enum ScreenGeometry {
    /// Index of the screen showing the largest part of `rect`, or `nil` if it is on no screen.
    static func overlappingScreen(for rect: CGRect, in screens: [CGRect]) -> Int? {
        screens.indices
            .map { (index: $0, area: area(screens[$0].intersection(rect))) }
            .filter { $0.area > 0 }
            .max { $0.area < $1.area }?
            .index
    }

    /// Index of the screen showing the largest part of `rect`; if it is on no screen, the screen nearest to its
    /// center. `nil` only without screens.
    static func screen(for rect: CGRect, in screens: [CGRect]) -> Int? {
        if let index = overlappingScreen(for: rect, in: screens) {
            return index
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return screens.indices.min { distance(from: center, to: screens[$0]) < distance(from: center, to: screens[$1]) }
    }

    /// Origin that moves `rect` the shortest way to lie completely inside `bounds`. A side that doesn't fit is aligned
    /// to the left or bottom edge.
    static func clampedOrigin(of rect: CGRect, into bounds: CGRect) -> CGPoint {
        CGPoint(
            x: max(bounds.minX, min(rect.minX, bounds.maxX - rect.width)),
            y: max(bounds.minY, min(rect.minY, bounds.maxY - rect.height)))
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
