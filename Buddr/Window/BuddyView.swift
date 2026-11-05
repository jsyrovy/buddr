import SwiftUI

/// Root view of the buddy panel.
struct BuddyView: View {
    let animation: BuddyAnimationDriver
    let scale: Int

    var body: some View {
        SpriteCanvas(
            frame: animation.sprite, gridWidth: SheepSprites.canvasWidth, gridHeight: SheepSprites.canvasHeight,
            scale: scale)
    }

    static func size(scale: Int) -> CGSize {
        SpriteCanvas.size(gridWidth: SheepSprites.canvasWidth, gridHeight: SheepSprites.canvasHeight, scale: scale)
    }
}
