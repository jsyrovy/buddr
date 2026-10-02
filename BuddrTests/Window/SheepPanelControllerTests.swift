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

    @Test func defaultPositionKeepsThePanelInsideTheVisibleFrame() {
        let visibleFrame = NSRect(x: 52, y: 0, width: 1460, height: 949)
        let size = SheepView.size(scale: 6)
        let origin = SheepPanelController.defaultOrigin(panelSize: size, visibleFrame: visibleFrame)
        #expect(visibleFrame.contains(NSRect(origin: origin, size: size)))
        // Bottom-right corner.
        #expect(origin.x + size.width > visibleFrame.midX)
        #expect(origin.y < visibleFrame.midY)
    }

    @Test func panelNeverTakesFocusAndFloatsOnEverySpace() {
        let panel = SheepPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10))
        #expect(!panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior.isSuperset(of: [.canJoinAllSpaces, .stationary]))
    }
}
