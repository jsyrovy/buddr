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
}
