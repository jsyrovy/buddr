import Foundation

/// A small proportional pixel font for the name plate under the sheep: glyphs 5 pixels wide at most (some symbols are
/// wider), 7 rows up to the cap height plus 2 for descenders, 1 pixel between glyphs.
///
/// Lowercase letters with a caron, an acute or a ring get the mark drawn in the two rows above the x-height; after a
/// letter with an ascender, a caron becomes an apostrophe-like mark to its right (`ď`, `ť`). Capitals have no room
/// above them and are drawn without their marks, like letters with other marks. Characters without a glyph become `?`.
enum PixelFont {
    /// Height of every line of text in pixels.
    static let height = 9
    /// Pixels between two glyphs.
    static let spacing = 1
    static let ink: Character = "#"
    static let ellipsis: Character = "…"

    /// Glyph grids: `#` is ink, `.` is empty. 7 rows, or 9 for glyphs reaching below the baseline.
    static let glyphs: [Character: [String]] = [
        // Lowercase: x-height rows 2–6, ascenders from row 0, descenders in rows 7–8.
        "a": [
            ".....",
            ".....",
            ".###.",
            "....#",
            ".####",
            "#...#",
            ".####",
        ],
        "b": [
            "#....",
            "#....",
            "####.",
            "#...#",
            "#...#",
            "#...#",
            "####.",
        ],
        "c": [
            "....",
            "....",
            ".###",
            "#...",
            "#...",
            "#...",
            ".###",
        ],
        "d": [
            "....#",
            "....#",
            ".####",
            "#...#",
            "#...#",
            "#...#",
            ".####",
        ],
        "e": [
            ".....",
            ".....",
            ".###.",
            "#...#",
            "#####",
            "#....",
            ".###.",
        ],
        "f": [
            "..##",
            ".#..",
            "####",
            ".#..",
            ".#..",
            ".#..",
            ".#..",
        ],
        "g": [
            ".....",
            ".....",
            ".####",
            "#...#",
            "#...#",
            "#...#",
            ".####",
            "....#",
            ".###.",
        ],
        "h": [
            "#....",
            "#....",
            "####.",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
        ],
        "i": [
            "#",
            ".",
            "#",
            "#",
            "#",
            "#",
            "#",
        ],
        "j": [
            "..#",
            "...",
            "..#",
            "..#",
            "..#",
            "..#",
            "..#",
            "..#",
            "##.",
        ],
        "k": [
            "#...",
            "#...",
            "#..#",
            "#.#.",
            "##..",
            "#.#.",
            "#..#",
        ],
        "l": [
            "#.",
            "#.",
            "#.",
            "#.",
            "#.",
            "#.",
            ".#",
        ],
        "m": [
            ".....",
            ".....",
            "##.#.",
            "#.#.#",
            "#.#.#",
            "#.#.#",
            "#.#.#",
        ],
        "n": [
            ".....",
            ".....",
            "####.",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
        ],
        "o": [
            ".....",
            ".....",
            ".###.",
            "#...#",
            "#...#",
            "#...#",
            ".###.",
        ],
        "p": [
            ".....",
            ".....",
            "####.",
            "#...#",
            "#...#",
            "#...#",
            "####.",
            "#....",
            "#....",
        ],
        "q": [
            ".....",
            ".....",
            ".####",
            "#...#",
            "#...#",
            "#...#",
            ".####",
            "....#",
            "....#",
        ],
        "r": [
            "....",
            "....",
            "#.##",
            "##..",
            "#...",
            "#...",
            "#...",
        ],
        "s": [
            "....",
            "....",
            ".###",
            "#...",
            ".##.",
            "...#",
            "###.",
        ],
        "t": [
            ".#.",
            ".#.",
            "###",
            ".#.",
            ".#.",
            ".#.",
            "..#",
        ],
        "u": [
            ".....",
            ".....",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            ".####",
        ],
        "v": [
            ".....",
            ".....",
            "#...#",
            "#...#",
            "#...#",
            ".#.#.",
            "..#..",
        ],
        "w": [
            ".....",
            ".....",
            "#...#",
            "#...#",
            "#.#.#",
            "#.#.#",
            ".#.#.",
        ],
        "x": [
            ".....",
            ".....",
            "#...#",
            ".#.#.",
            "..#..",
            ".#.#.",
            "#...#",
        ],
        "y": [
            ".....",
            ".....",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            ".####",
            "....#",
            ".###.",
        ],
        "z": [
            ".....",
            ".....",
            "#####",
            "...#.",
            "..#..",
            ".#...",
            "#####",
        ],
        // Uppercase and digits: rows 0–6.
        "A": [
            ".###.",
            "#...#",
            "#...#",
            "#####",
            "#...#",
            "#...#",
            "#...#",
        ],
        "B": [
            "####.",
            "#...#",
            "#...#",
            "####.",
            "#...#",
            "#...#",
            "####.",
        ],
        "C": [
            ".###.",
            "#...#",
            "#....",
            "#....",
            "#....",
            "#...#",
            ".###.",
        ],
        "D": [
            "####.",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            "####.",
        ],
        "E": [
            "#####",
            "#....",
            "#....",
            "####.",
            "#....",
            "#....",
            "#####",
        ],
        "F": [
            "#####",
            "#....",
            "#....",
            "####.",
            "#....",
            "#....",
            "#....",
        ],
        "G": [
            ".###.",
            "#...#",
            "#....",
            "#.###",
            "#...#",
            "#...#",
            ".####",
        ],
        "H": [
            "#...#",
            "#...#",
            "#...#",
            "#####",
            "#...#",
            "#...#",
            "#...#",
        ],
        "I": [
            "###",
            ".#.",
            ".#.",
            ".#.",
            ".#.",
            ".#.",
            "###",
        ],
        "J": [
            "..###",
            "...#.",
            "...#.",
            "...#.",
            "...#.",
            "#..#.",
            ".##..",
        ],
        "K": [
            "#...#",
            "#..#.",
            "#.#..",
            "##...",
            "#.#..",
            "#..#.",
            "#...#",
        ],
        "L": [
            "#....",
            "#....",
            "#....",
            "#....",
            "#....",
            "#....",
            "#####",
        ],
        "M": [
            "#...#",
            "##.##",
            "#.#.#",
            "#.#.#",
            "#...#",
            "#...#",
            "#...#",
        ],
        "N": [
            "#...#",
            "#...#",
            "##..#",
            "#.#.#",
            "#..##",
            "#...#",
            "#...#",
        ],
        "O": [
            ".###.",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            ".###.",
        ],
        "P": [
            "####.",
            "#...#",
            "#...#",
            "####.",
            "#....",
            "#....",
            "#....",
        ],
        "Q": [
            ".###.",
            "#...#",
            "#...#",
            "#...#",
            "#.#.#",
            "#..#.",
            ".##.#",
        ],
        "R": [
            "####.",
            "#...#",
            "#...#",
            "####.",
            "#.#..",
            "#..#.",
            "#...#",
        ],
        "S": [
            ".####",
            "#....",
            "#....",
            ".###.",
            "....#",
            "....#",
            "####.",
        ],
        "T": [
            "#####",
            "..#..",
            "..#..",
            "..#..",
            "..#..",
            "..#..",
            "..#..",
        ],
        "U": [
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            ".###.",
        ],
        "V": [
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            ".#.#.",
            "..#..",
        ],
        "W": [
            "#...#",
            "#...#",
            "#...#",
            "#.#.#",
            "#.#.#",
            "#.#.#",
            ".#.#.",
        ],
        "X": [
            "#...#",
            "#...#",
            ".#.#.",
            "..#..",
            ".#.#.",
            "#...#",
            "#...#",
        ],
        "Y": [
            "#...#",
            "#...#",
            ".#.#.",
            "..#..",
            "..#..",
            "..#..",
            "..#..",
        ],
        "Z": [
            "#####",
            "....#",
            "...#.",
            "..#..",
            ".#...",
            "#....",
            "#####",
        ],
        "0": [
            ".###.",
            "#...#",
            "#..##",
            "#.#.#",
            "##..#",
            "#...#",
            ".###.",
        ],
        "1": [
            "..#.",
            ".##.",
            "#.#.",
            "..#.",
            "..#.",
            "..#.",
            ".###",
        ],
        "2": [
            ".###.",
            "#...#",
            "....#",
            "...#.",
            "..#..",
            ".#...",
            "#####",
        ],
        "3": [
            ".###.",
            "#...#",
            "....#",
            "..##.",
            "....#",
            "#...#",
            ".###.",
        ],
        "4": [
            "...#.",
            "..##.",
            ".#.#.",
            "#..#.",
            "#####",
            "...#.",
            "...#.",
        ],
        "5": [
            "#####",
            "#....",
            "####.",
            "....#",
            "....#",
            "#...#",
            ".###.",
        ],
        "6": [
            "..##.",
            ".#...",
            "#....",
            "####.",
            "#...#",
            "#...#",
            ".###.",
        ],
        "7": [
            "#####",
            "....#",
            "...#.",
            "..#..",
            ".#...",
            ".#...",
            ".#...",
        ],
        "8": [
            ".###.",
            "#...#",
            "#...#",
            ".###.",
            "#...#",
            "#...#",
            ".###.",
        ],
        "9": [
            ".###.",
            "#...#",
            "#...#",
            ".####",
            "....#",
            "...#.",
            ".##..",
        ],
        // Punctuation and symbols.
        " ": [
            "...",
            "...",
            "...",
            "...",
            "...",
            "...",
            "...",
        ],
        ".": [
            ".",
            ".",
            ".",
            ".",
            ".",
            ".",
            "#",
        ],
        ",": [
            "..",
            "..",
            "..",
            "..",
            "..",
            "..",
            ".#",
            "#.",
            "..",
        ],
        ":": [
            ".",
            ".",
            "#",
            ".",
            ".",
            "#",
            ".",
        ],
        ";": [
            "..",
            "..",
            ".#",
            "..",
            "..",
            ".#",
            ".#",
            "#.",
            "..",
        ],
        "!": [
            "#",
            "#",
            "#",
            "#",
            "#",
            ".",
            "#",
        ],
        "?": [
            ".###.",
            "#...#",
            "....#",
            "...#.",
            "..#..",
            ".....",
            "..#..",
        ],
        "'": [
            "#",
            "#",
            ".",
            ".",
            ".",
            ".",
            ".",
        ],
        "\"": [
            "#.#",
            "#.#",
            "...",
            "...",
            "...",
            "...",
            "...",
        ],
        "`": [
            "#.",
            ".#",
            "..",
            "..",
            "..",
            "..",
            "..",
        ],
        "_": [
            "####",
            "....",
            "....",
            "....",
            "....",
            "....",
            "....",
            "####",
            "....",
        ],
        "+": [
            "...",
            "...",
            ".#.",
            "###",
            ".#.",
            "...",
            "...",
        ],
        "=": [
            "...",
            "...",
            "###",
            "...",
            "###",
            "...",
            "...",
        ],
        "·": [
            ".",
            ".",
            ".",
            "#",
            ".",
            ".",
            ".",
        ],
        "…": [
            ".....",
            ".....",
            ".....",
            ".....",
            ".....",
            ".....",
            "#.#.#",
        ],
        "-": [
            "...",
            "...",
            "...",
            "###",
            "...",
            "...",
            "...",
        ],
        "–": [
            "....",
            "....",
            "....",
            "####",
            "....",
            "....",
            "....",
        ],
        "—": [
            "......",
            "......",
            "......",
            "######",
            "......",
            "......",
            "......",
        ],
        "/": [
            "..#",
            "..#",
            ".#.",
            ".#.",
            ".#.",
            "#..",
            "#..",
        ],
        "\\": [
            "#..",
            "#..",
            ".#.",
            ".#.",
            ".#.",
            "..#",
            "..#",
        ],
        "|": [
            "#",
            "#",
            "#",
            "#",
            "#",
            "#",
            "#",
        ],
        "(": [
            ".#",
            "#.",
            "#.",
            "#.",
            "#.",
            "#.",
            ".#",
        ],
        ")": [
            "#.",
            ".#",
            ".#",
            ".#",
            ".#",
            ".#",
            "#.",
        ],
        "[": [
            "##",
            "#.",
            "#.",
            "#.",
            "#.",
            "#.",
            "##",
        ],
        "]": [
            "##",
            ".#",
            ".#",
            ".#",
            ".#",
            ".#",
            "##",
        ],
        "{": [
            "..#",
            ".#.",
            ".#.",
            "#..",
            ".#.",
            ".#.",
            "..#",
        ],
        "}": [
            "#..",
            ".#.",
            ".#.",
            "..#",
            ".#.",
            ".#.",
            "#..",
        ],
        "<": [
            "...",
            "..#",
            ".#.",
            "#..",
            ".#.",
            "..#",
            "...",
        ],
        ">": [
            "...",
            "#..",
            ".#.",
            "..#",
            ".#.",
            "#..",
            "...",
        ],
        "^": [
            ".#.",
            "#.#",
            "...",
            "...",
            "...",
            "...",
            "...",
        ],
        "~": [
            ".....",
            ".....",
            ".....",
            ".#..#",
            "#.##.",
            ".....",
            ".....",
        ],
        "*": [
            "...",
            "#.#",
            ".#.",
            "#.#",
            "...",
            "...",
            "...",
        ],
        "#": [
            ".#.#.",
            ".#.#.",
            "#####",
            ".#.#.",
            "#####",
            ".#.#.",
            ".#.#.",
        ],
        "%": [
            "##..#",
            "##..#",
            "...#.",
            "..#..",
            ".#...",
            "#..##",
            "#..##",
        ],
        "&": [
            ".##..",
            "#..#.",
            "#.#..",
            ".#...",
            "#.#.#",
            "#..#.",
            ".##.#",
        ],
        "@": [
            ".###.",
            "#...#",
            "#.###",
            "#.#.#",
            "#.###",
            "#....",
            ".###.",
        ],
        "$": [
            "..#..",
            ".####",
            "#.#..",
            ".###.",
            "..#.#",
            "####.",
            "..#..",
        ],
    ]

    /// Every glyph with its character, for validation in tests.
    static let allGlyphs: [(character: Character, rows: [String])] = glyphs.sorted { $0.key < $1.key }.map {
        ($0.key, $0.value)
    }

    /// Combining marks drawn above lowercase letters, centered (leaning right).
    private static let marks: [Unicode.Scalar: [String]] = [
        caron: [
            "#.#",
            ".#.",
        ],
        "\u{0301}": [  // acute
            ".#",
            "#.",
        ],
        "\u{030A}": [  // ring
            "##",
            "##",
        ],
    ]
    private static let caron: Unicode.Scalar = "\u{030C}"

    // MARK: Glyphs

    /// The rows of the glyph drawing `character`, always `height` rows.
    static func glyph(for character: Character) -> [String] {
        if let rows = glyphs[character] {
            return padded(rows)
        }
        if character.isWhitespace {
            return glyph(for: " ")
        }
        let scalars = String(character).decomposedStringWithCanonicalMapping.unicodeScalars
        guard let base = scalars.first, let rows = glyphs[Character(base)] else {
            return glyph(for: "?")
        }
        var glyph = padded(rows)
        guard base.properties.isLowercase, let mark = scalars.dropFirst().first(where: { marks[$0] != nil }) else {
            return glyph
        }
        if base == "i" {
            // Dotless: the mark takes the place of the dot.
            glyph[0] = String(repeating: ".", count: glyph[0].count)
        }
        if let ascender = lastInkColumn(of: glyph.prefix(2)) {
            // No room above an ascender: a caron goes to the right, other marks are left out.
            return mark == caron ? addingApostrophe(to: glyph, at: ascender + 2) : glyph
        }
        return adding(marks[mark]!, to: glyph)
    }

    private static func padded(_ rows: [String]) -> [String] {
        rows + Array(repeating: String(repeating: ".", count: rows[0].count), count: height - rows.count)
    }

    private static func lastInkColumn(of rows: some Sequence<String>) -> Int? {
        rows.compactMap { row in row.lastIndex(of: ink).map { row.distance(from: row.startIndex, to: $0) } }.max()
    }

    private static func adding(_ mark: [String], to glyph: [String]) -> [String] {
        let width = glyph[0].count
        let markWidth = mark[0].count
        let offset = max(0, (width - markWidth + 1) / 2)
        var result = widened(glyph, to: max(width, offset + markWidth))
        for (row, markRow) in mark.enumerated() {
            var pixels = Array(result[row])
            for (column, pixel) in markRow.enumerated() where pixel == ink {
                pixels[offset + column] = ink
            }
            result[row] = String(pixels)
        }
        return result
    }

    private static func addingApostrophe(to glyph: [String], at column: Int) -> [String] {
        let apostrophe = (0..<column).map { _ in "." }.joined() + "#"
        return adding([apostrophe, apostrophe], to: widened(glyph, to: column + 1))
    }

    private static func widened(_ glyph: [String], to width: Int) -> [String] {
        glyph.map { $0 + String(repeating: ".", count: max(0, width - $0.count)) }
    }

    // MARK: Text

    /// Width of `text` in pixels.
    static func width(of text: String) -> Int {
        let widths = text.map { glyph(for: $0)[0].count }
        return widths.reduce(0, +) + spacing * max(0, widths.count - 1)
    }

    /// `text` in one line, `height` pixels tall, ink in `color`.
    static func sprite(for text: String, color: PixelColor) -> PixelSprite {
        let glyphs = text.map(glyph(for:))
        let gap = String(repeating: ".", count: spacing)
        let rows = (0..<height).map { row in glyphs.map { $0[row] }.joined(separator: gap) }
        let pixels = rows.flatMap { row in row.map { $0 == ink ? color : nil } }
        return PixelSprite(width: rows[0].count, height: height, pixels: pixels)
    }

    /// The text of `plate`, at most `maxWidth` pixels wide: the title is shortened with `…`, keeping the machine and
    /// workspace before it and the `+N` after it. When even those don't fit, the whole text is cut at the end.
    static func truncated(_ plate: NamePlate, maxWidth: Int) -> String {
        let text = plate.text
        guard width(of: text) > maxWidth else { return text }
        var title = Substring(plate.title)
        while !title.isEmpty {
            title.removeLast()
            let shortened = plate.text(title: title.trimmingTrailingWhitespace() + String(ellipsis))
            if width(of: shortened) <= maxWidth { return shortened }
        }
        return truncated(text, maxWidth: maxWidth)
    }

    /// `text` cut at the end with `…` to be at most `maxWidth` pixels wide; empty if not even `…` fits.
    static func truncated(_ text: String, maxWidth: Int) -> String {
        guard width(of: text) > maxWidth else { return text }
        var kept = Substring(text)
        while !kept.isEmpty {
            kept.removeLast()
            let shortened = kept.trimmingTrailingWhitespace() + String(ellipsis)
            if width(of: shortened) <= maxWidth { return shortened }
        }
        return ""
    }
}

extension Substring {
    fileprivate func trimmingTrailingWhitespace() -> String {
        String(self[..<(lastIndex { !$0.isWhitespace }.map(index(after:)) ?? startIndex)])
    }
}
