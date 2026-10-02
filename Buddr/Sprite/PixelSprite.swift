/// An sRGB color of a single sprite pixel.
struct PixelColor: Hashable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

/// A rectangular grid of pixels; `nil` pixels are transparent.
///
/// Sprites are written as rows of characters, one character per pixel. `.` is transparent, every other character is
/// looked up in a palette.
struct PixelSprite: Hashable, Sendable {
    static let transparent: Character = "."

    let width: Int
    let height: Int
    private let pixels: [PixelColor?]

    init(width: Int, height: Int, pixels: [PixelColor?]) {
        precondition(pixels.count == width * height, "Pixel count does not match the sprite size")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Builds a sprite from character rows. The rows must be valid, see `problems(rows:palette:)`.
    init(rows: [String], palette: [Character: PixelColor]) {
        let problems = Self.problems(rows: rows, palette: palette)
        precondition(problems.isEmpty, "Invalid sprite: \(problems.joined(separator: "; "))")
        let pixels = rows.flatMap { row in
            row.map { character in character == Self.transparent ? nil : palette[character] }
        }
        self.init(width: rows[0].count, height: rows.count, pixels: pixels)
    }

    /// Describes everything wrong with the given rows; empty when they form a valid sprite.
    static func problems(rows: [String], palette: [Character: PixelColor]) -> [String] {
        guard let width = rows.first?.count, width > 0 else { return ["sprite has no pixels"] }
        var problems: [String] = []
        for (index, row) in rows.enumerated() {
            if row.count != width {
                problems.append("row \(index) has \(row.count) pixels, expected \(width)")
            }
            for character in Set(row) where character != transparent && palette[character] == nil {
                problems.append("row \(index) uses unknown color '\(character)'")
            }
        }
        return problems
    }

    func color(x: Int, y: Int) -> PixelColor? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        return pixels[y * width + x]
    }

    /// Returns a sprite one pixel larger on every side, with an outline around all opaque pixels
    /// (including diagonal neighbours).
    func outlined(with outline: PixelColor) -> PixelSprite {
        let newWidth = width + 2
        let newHeight = height + 2
        var result: [PixelColor?] = Array(repeating: nil, count: newWidth * newHeight)
        for y in 0..<newHeight {
            for x in 0..<newWidth {
                if let own = color(x: x - 1, y: y - 1) {
                    result[y * newWidth + x] = own
                    continue
                }
                let touchesOpaquePixel = (-1...1).contains { dy in
                    (-1...1).contains { dx in color(x: x - 1 + dx, y: y - 1 + dy) != nil }
                }
                if touchesOpaquePixel {
                    result[y * newWidth + x] = outline
                }
            }
        }
        return PixelSprite(width: newWidth, height: newHeight, pixels: result)
    }
}
