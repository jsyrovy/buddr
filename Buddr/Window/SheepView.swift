import SwiftUI

/// Root view of the sheep panel.
struct SheepView: View {
    let scale: Int

    var body: some View {
        SpriteCanvas(
            frame: SheepSprites.standingFrame, gridWidth: SheepSprites.canvasWidth,
            gridHeight: SheepSprites.canvasHeight, scale: scale)
    }
}
