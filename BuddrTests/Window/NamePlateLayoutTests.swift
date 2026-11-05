import CoreGraphics
import Testing

@testable import Buddr

struct NamePlateLayoutTests {
    private static let visibleFrame = CGRect(x: 0, y: 80, width: 1512, height: 870)
    private static let plateSize = CGSize(width: 160, height: 26)
    private static let buddySize = CGSize(width: 132, height: 120)
    private static let buddyY: CGFloat = 400

    private static func frame(buddyX: CGFloat, plateWidth: CGFloat = plateSize.width) -> CGRect {
        NamePlateLayout.frame(
            plateSize: CGSize(width: plateWidth, height: plateSize.height),
            buddyFrame: CGRect(origin: CGPoint(x: buddyX, y: buddyY), size: buddySize), visibleFrame: visibleFrame,
            plateScale: 2)
    }

    @Test func plateScaleIsAThirdOfTheBuddyScale() {
        #expect([4, 6, 8].map { NamePlateLayout.plateScale(buddyScale: $0) } == [1, 2, 2])
        #expect(NamePlateLayout.plateScale(buddyScale: 1) == 1)
    }

    @Test func reservedRoomHoldsThePlateAndTheGap() {
        let plate = SheepSprites.Plate.self
        #expect(NamePlateLayout.reservedHeight(buddyScale: 6) == CGFloat((plate.height + plate.gap) * 2))
    }

    @Test func plateIsCenteredUnderTheBuddy() {
        let frame = Self.frame(buddyX: 600)
        #expect(frame.midX == 600 + Self.buddySize.width / 2)
        #expect(frame.size == Self.plateSize)
        // The gap of 2 plate pixels between the feet and the plate.
        let feet = Self.buddyY
        #expect(frame.maxY == feet - 4)
    }

    @Test func plateStaysInsideTheVisibleFrame() {
        // Bottom-right corner: shifted left.
        #expect(Self.frame(buddyX: 1512 - 132 - 4).maxX == 1512)
        // Left edge: shifted right.
        #expect(Self.frame(buddyX: 0).minX == 0)
    }

    @Test func aPlateWiderThanTheScreenStartsAtItsLeftEdge() {
        #expect(Self.frame(buddyX: 600, plateWidth: 2000).minX == 0)
    }
}
