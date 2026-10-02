import SwiftUI

/// Draws a `SpriteFrame` as crisp pixels: every sprite pixel becomes a `scale` × `scale` point square.
struct SpriteCanvas: View {
    let frame: SpriteFrame
    let gridWidth: Int
    let gridHeight: Int
    let scale: Int

    var body: some View {
        Canvas { context, _ in
            for layer in frame.layers {
                for (color, path) in paths(for: layer) {
                    context.fill(path, with: .color(Color(color)))
                }
            }
        }
        .frame(width: CGFloat(gridWidth * scale), height: CGFloat(gridHeight * scale))
        .opacity(frame.opacity)
    }

    /// One path per color keeps the number of fill operations small; layers are still drawn in order.
    private func paths(for layer: SpriteLayer) -> [PixelColor: Path] {
        var paths: [PixelColor: Path] = [:]
        let size = CGFloat(scale)
        for y in 0..<layer.sprite.height {
            for x in 0..<layer.sprite.width {
                guard let color = layer.sprite.color(x: x, y: y) else { continue }
                let rect = CGRect(
                    x: CGFloat(layer.x + x) * size, y: CGFloat(layer.y + y) * size, width: size, height: size)
                paths[color, default: Path()].addRect(rect)
            }
        }
        return paths
    }
}

extension Color {
    init(_ pixel: PixelColor) {
        self.init(
            .sRGB, red: Double(pixel.red) / 255, green: Double(pixel.green) / 255, blue: Double(pixel.blue) / 255)
    }
}
