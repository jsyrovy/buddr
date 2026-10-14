import AppKit
import Testing

@testable import Buddr

@MainActor
struct SheepPanelControllerTests {
    @Test func panelHasTheSizeOfTheSpriteCanvasBeforeItIsShown() {
        let controller = SheepPanelController(animation: SheepAnimationDriver(), scale: 6)
        #expect(
            controller.frame.size == CGSize(width: SheepSprites.canvasWidth * 6, height: SheepSprites.canvasHeight * 6))
    }

    @Test func defaultPositionKeepsThePanelAndTheRoomBelowItInsideTheVisibleFrame() {
        let visibleFrame = NSRect(x: 52, y: 0, width: 1460, height: 949)
        let size = SheepView.size(scale: 6)
        let origin = SheepPanelController.defaultOrigin(panelSize: size, visibleFrame: visibleFrame, reservedBelow: 30)
        let withRoom = NSRect(x: origin.x, y: origin.y - 30, width: size.width, height: size.height + 30)
        #expect(visibleFrame.contains(withRoom))
        // Bottom-right corner.
        #expect(origin.x + size.width > visibleFrame.midX)
        #expect(origin.y < visibleFrame.midY)
        // The plate keeps the same margin from the bottom as the panel from the right.
        #expect(withRoom.minY - visibleFrame.minY == visibleFrame.maxX - withRoom.maxX)
    }

    @Test func clampingKeepsRoomBelowThePanel() {
        let visibleFrame = NSRect(x: 0, y: 80, width: 1512, height: 870)
        let size = CGSize(width: 132, height: 120)
        let clamp = { (origin: NSPoint) in
            SheepPanelController.onScreenOrigin(
                of: NSRect(origin: origin, size: size), in: visibleFrame, reservedBelow: 30)
        }
        // Too low: moved up so that the room ends at the bottom of the visible frame (above the Dock).
        #expect(clamp(NSPoint(x: 400, y: 90)) == NSPoint(x: 400, y: 110))
        #expect(clamp(NSPoint(x: 400, y: -500)) == NSPoint(x: 400, y: 110))
        // High enough: unchanged. The top and the sides are clamped as before.
        #expect(clamp(NSPoint(x: 400, y: 110)) == NSPoint(x: 400, y: 110))
        #expect(clamp(NSPoint(x: 1500, y: 2000)) == NSPoint(x: 1512 - 132, y: 950 - 120))
        #expect(clamp(NSPoint(x: -20, y: 500)) == NSPoint(x: 0, y: 500))
    }

    @Test func panelNeverTakesFocusAndFloatsOnEverySpace() {
        let panel = SheepPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10))
        #expect(!panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior.isSuperset(of: [.canJoinAllSpaces, .stationary]))
    }

    @Test func aDragThatBarelyMovedThePanelIsAClick() {
        let start = NSPoint(x: 100, y: 200)
        let tolerance = SheepPanel.clickTolerance
        #expect(SheepPanel.isClick(dragStart: start, dragEnd: start))
        #expect(SheepPanel.isClick(dragStart: start, dragEnd: NSPoint(x: 100 - tolerance, y: 200 + tolerance)))
        #expect(!SheepPanel.isClick(dragStart: start, dragEnd: NSPoint(x: 100 + tolerance + 1, y: 200)))
        #expect(!SheepPanel.isClick(dragStart: start, dragEnd: NSPoint(x: 100, y: 200 - tolerance - 1)))
    }
}
