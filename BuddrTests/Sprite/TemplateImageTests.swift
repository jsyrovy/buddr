import AppKit
import Testing

@testable import Buddr

@MainActor
struct TemplateImageTests {
    private static let palette: [Character: PixelColor] = ["X": PixelColor(red: 255, green: 0, blue: 0)]

    /// Draws the image into a bitmap with `backingScale` device pixels per point and returns the alpha values, top
    /// row first.
    private func alpha(of image: NSImage, backingScale: Int) throws -> (width: Int, height: Int, values: [UInt8]) {
        let width = Int((image.size.width * Double(backingScale)).rounded())
        let height = Int((image.size.height * Double(backingScale)).rounded())
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(
                CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.scaleBy(x: CGFloat(backingScale), y: CGFloat(backingScale))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: NSRect(origin: .zero, size: image.size))
            NSGraphicsContext.restoreGraphicsState()
        }
        return (width, height, stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] })
    }

    @Test func isATemplateSizedByThePointsPerPixel() {
        let sprite = PixelSprite(rows: ["X.X", "..."], palette: Self.palette)
        let image = NSImage.template(from: sprite, pointsPerPixel: 1.5)

        #expect(image.isTemplate)
        #expect(image.size == NSSize(width: 4.5, height: 3))
    }

    @Test func drawsOpaquePixelsAsSharpSquares() throws {
        let rows = ["XX.", ".X.", "..X", "X.."]
        let sprite = PixelSprite(rows: rows, palette: Self.palette)
        // 1.5 points per pixel at 2× is 3 × 3 device pixels per sprite pixel.
        let image = NSImage.template(from: sprite, pointsPerPixel: 1.5)
        let backingScale = 2
        let devicePixelsPerPixel = 3

        let bitmap = try alpha(of: image, backingScale: backingScale)

        #expect(bitmap.width == sprite.width * devicePixelsPerPixel)
        #expect(bitmap.height == sprite.height * devicePixelsPerPixel)
        // Every device pixel is fully opaque or fully transparent, as its sprite pixel: no smoothing at the edges.
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let opaque = sprite.color(x: x / devicePixelsPerPixel, y: y / devicePixelsPerPixel) != nil
                #expect(bitmap.values[y * bitmap.width + x] == (opaque ? 255 : 0), "pixel (\(x), \(y))")
            }
        }
    }
}
