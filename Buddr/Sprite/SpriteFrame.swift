/// A sprite placed at a pixel offset within the sprite canvas.
struct SpriteLayer: Hashable, Sendable {
    let sprite: PixelSprite
    let x: Int
    let y: Int
}

/// One rendered picture: layers drawn bottom to top, with an overall opacity.
struct SpriteFrame: Hashable, Sendable {
    var layers: [SpriteLayer]
    var opacity: Double = 1

    /// The frame flipped horizontally within a canvas `canvasWidth` pixels wide.
    func mirrored(canvasWidth: Int) -> SpriteFrame {
        let flipped = layers.map { layer in
            SpriteLayer(sprite: layer.sprite.mirrored(), x: canvasWidth - layer.x - layer.sprite.width, y: layer.y)
        }
        return SpriteFrame(layers: flipped, opacity: opacity)
    }
}
