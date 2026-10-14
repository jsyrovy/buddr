import CoreGraphics
import Testing

@testable import Buddr

struct NamePlateLayoutTests {
    private static let visibleFrame = CGRect(x: 0, y: 80, width: 1512, height: 870)
    private static let plateSize = CGSize(width: 160, height: 26)
    private static let sheepSize = CGSize(width: 132, height: 120)
    private static let sheepY: CGFloat = 400

    private static func frame(sheepX: CGFloat, plateWidth: CGFloat = plateSize.width) -> CGRect {
        NamePlateLayout.frame(
            plateSize: CGSize(width: plateWidth, height: plateSize.height),
            sheepFrame: CGRect(origin: CGPoint(x: sheepX, y: sheepY), size: sheepSize), visibleFrame: visibleFrame,
            plateScale: 2)
    }

    @Test func plateScaleIsAThirdOfTheSheepScale() {
        #expect([4, 6, 8].map { NamePlateLayout.plateScale(sheepScale: $0) } == [1, 2, 2])
        #expect(NamePlateLayout.plateScale(sheepScale: 1) == 1)
    }

    @Test func reservedRoomHoldsThePlateAndTheGap() {
        let plate = SheepSprites.Plate.self
        #expect(NamePlateLayout.reservedHeight(sheepScale: 6) == CGFloat((plate.height + plate.gap) * 2))
    }

    @Test func plateIsCenteredUnderTheSheep() {
        let frame = Self.frame(sheepX: 600)
        #expect(frame.midX == 600 + Self.sheepSize.width / 2)
        #expect(frame.size == Self.plateSize)
        // The gap of 2 plate pixels between the feet and the plate.
        let feet = Self.sheepY
        #expect(frame.maxY == feet - 4)
    }

    @Test func plateStaysInsideTheVisibleFrame() {
        // Bottom-right corner: shifted left.
        #expect(Self.frame(sheepX: 1512 - 132 - 4).maxX == 1512)
        // Left edge: shifted right.
        #expect(Self.frame(sheepX: 0).minX == 0)
    }

    @Test func aPlateWiderThanTheScreenStartsAtItsLeftEdge() {
        #expect(Self.frame(sheepX: 600, plateWidth: 2000).minX == 0)
    }
}
