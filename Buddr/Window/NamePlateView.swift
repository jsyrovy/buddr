import SwiftUI

/// Content of the name plate panel: the plate sprite in crisp pixels.
struct NamePlateView: View {
    let sprite: PixelSprite
    let scale: Int

    var body: some View {
        SpriteCanvas(
            frame: SpriteFrame(layers: [SpriteLayer(sprite: sprite, x: 0, y: 0)]), gridWidth: sprite.width,
            gridHeight: sprite.height, scale: scale)
    }
}
