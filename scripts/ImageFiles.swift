import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Writing images, shared by the scripts compiled with the app's sources (screenshots.swift, previews.swift): the
// Makefile compiles this file into both.

enum ImageFiles {
    /// Redrawn into 8-bit sRGB.
    static func normalized(_ image: CGImage) -> CGImage {
        let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()!
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try write([normalized(image)], to: url, .png, frameProperties: [nil])
    }

    /// An animated GIF that loops forever: `image(i)`, rendered at `scale` pixels per point, shown for `durations[i]`.
    /// Returns the width of its frames in pixels.
    @MainActor @discardableResult
    static func writeGIF<Content: View>(
        _ durations: [Duration], to url: URL, scale: Int = 1, image: (Int) -> Content
    ) throws -> Int {
        let images = durations.indices.map { index in
            let renderer = ImageRenderer(content: image(index))
            renderer.scale = CGFloat(scale)
            return normalized(renderer.cgImage!)
        }
        let delays = durations.map { duration in
            let seconds = duration / .seconds(1)
            return [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: seconds, kCGImagePropertyGIFUnclampedDelayTime: seconds,
                ]
            ] as CFDictionary
        }
        try write(
            images, to: url, .gif, frameProperties: delays,
            properties: [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        return images[0].width
    }

    static func write(
        _ images: [CGImage], to url: URL, _ type: UTType, frameProperties: [CFDictionary?],
        properties: CFDictionary? = nil
    ) throws {
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, type.identifier as CFString, images.count, nil)
        else { throw Failure("can't create \(url.lastPathComponent)") }
        if let properties { CGImageDestinationSetProperties(destination, properties) }
        for (image, frame) in zip(images, frameProperties) {
            CGImageDestinationAddImage(destination, image, frame)
        }
        guard CGImageDestinationFinalize(destination) else { throw Failure("can't write \(url.lastPathComponent)") }
    }
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
