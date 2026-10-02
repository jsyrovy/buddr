import CoreGraphics
import SwiftUI
import Testing

@testable import Buddr

@MainActor
struct SpriteCanvasTests {
    /// Premultiplied RGBA pixels in sRGB, top row first.
    struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func rgba(x: Int, y: Int) -> [UInt8] {
            let offset = (y * width + x) * 4
            return Array(bytes[offset..<offset + 4])
        }
    }

    private static let red = PixelColor(red: 255, green: 0, blue: 0)
    private static let blue = PixelColor(red: 0, green: 0, blue: 255)
    private static let palette: [Character: PixelColor] = ["R": red, "B": blue]

    /// Renders at one pixel per point.
    private func render(_ canvas: SpriteCanvas) throws -> Bitmap {
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(
                CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return Bitmap(width: width, height: height, bytes: bytes)
    }

    @Test func drawsEveryPixelAsASharpSquareWithLayersInOrder() throws {
        let body = PixelSprite(rows: ["RR", "R."], palette: Self.palette)
        let dot = PixelSprite(rows: ["B"], palette: Self.palette)
        // The dot covers the red pixel at (0, 1); the transparent pixel at (1, 1) stays transparent.
        let frame = SpriteFrame(layers: [SpriteLayer(sprite: body, x: 0, y: 0), SpriteLayer(sprite: dot, x: 0, y: 1)])
        let scale = 3
        let bitmap = try render(SpriteCanvas(frame: frame, gridWidth: 4, gridHeight: 3, scale: scale))

        #expect(bitmap.width == 4 * scale)
        #expect(bitmap.height == 3 * scale)
        let red: [UInt8] = [255, 0, 0, 255]
        let blue: [UInt8] = [0, 0, 255, 255]
        let clear: [UInt8] = [0, 0, 0, 0]
        let expected: [[[UInt8]]] = [
            [red, red, clear, clear],
            [blue, clear, clear, clear],
            [clear, clear, clear, clear],
        ]
        // Every point of a grid pixel has exactly its color: no smoothing at the edges.
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                #expect(bitmap.rgba(x: x, y: y) == expected[y / scale][x / scale], "pixel (\(x), \(y))")
            }
        }
    }

    @Test func appliesTheFrameOpacity() throws {
        let frame = SpriteFrame(
            layers: [SpriteLayer(sprite: PixelSprite(rows: ["R"], palette: Self.palette), x: 0, y: 0)], opacity: 0.5)
        let bitmap = try render(SpriteCanvas(frame: frame, gridWidth: 1, gridHeight: 1, scale: 2))

        let pixel = bitmap.rgba(x: 1, y: 1)
        #expect((126...129).contains(pixel[3]))
        // Premultiplied: the red channel matches the alpha, the others stay empty.
        #expect(pixel[0] == pixel[3])
        #expect(pixel[1] == 0 && pixel[2] == 0)
    }
}
