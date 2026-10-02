import CoreGraphics
import Testing

@testable import Buddr

struct ScreenGeometryTests {
    /// A built-in display with an external one above it, as in AppKit coordinates.
    private static let screens = [
        CGRect(x: 0, y: 0, width: 1512, height: 982),
        CGRect(x: -531, y: 982, width: 2560, height: 1440),
    ]

    @Test func picksTheScreenShowingMostOfTheRect() {
        let mostlyBelow = CGRect(x: 100, y: 900, width: 132, height: 120)
        let mostlyAbove = CGRect(x: 100, y: 950, width: 132, height: 120)
        #expect(ScreenGeometry.overlappingScreen(for: mostlyBelow, in: Self.screens) == 0)
        #expect(ScreenGeometry.overlappingScreen(for: mostlyAbove, in: Self.screens) == 1)
    }

    @Test func rectOffAllScreensBelongsToTheNearestOne() {
        let rightOfBuiltIn = CGRect(x: 1600, y: 100, width: 132, height: 120)
        let farLeftAbove = CGRect(x: -900, y: 2000, width: 132, height: 120)
        #expect(ScreenGeometry.overlappingScreen(for: rightOfBuiltIn, in: Self.screens) == nil)
        #expect(ScreenGeometry.screen(for: rightOfBuiltIn, in: Self.screens) == 0)
        #expect(ScreenGeometry.screen(for: farLeftAbove, in: Self.screens) == 1)
        #expect(ScreenGeometry.screen(for: rightOfBuiltIn, in: []) == nil)
    }

    @Test func clampingMovesTheRectInsideTheBounds() {
        let visible = CGRect(x: 52, y: 0, width: 1460, height: 949)
        let size = CGSize(width: 132, height: 120)
        func clamped(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            ScreenGeometry.clampedOrigin(of: CGRect(origin: CGPoint(x: x, y: y), size: size), into: visible)
        }
        #expect(clamped(500, 300) == CGPoint(x: 500, y: 300))
        #expect(clamped(1450, 300) == CGPoint(x: 1380, y: 300))
        #expect(clamped(-40, -60) == CGPoint(x: 52, y: 0))
        #expect(clamped(700, 900) == CGPoint(x: 700, y: 829))
    }

    @Test func sideThatDoesNotFitIsAlignedToTheLeftAndBottom() {
        let small = CGRect(x: 10, y: 20, width: 100, height: 50)
        let origin = ScreenGeometry.clampedOrigin(of: CGRect(x: 300, y: 300, width: 200, height: 80), into: small)
        #expect(origin == CGPoint(x: 10, y: 20))
    }
}
