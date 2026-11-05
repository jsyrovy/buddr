import SwiftUI

// Renders every clip of a buddy with the app's own code (`Buddy.allClips`, `SpriteCanvas`), for designing and reviewing
// a buddy (the new-buddy skill): a looping GIF of every clip on a dark and a light desktop, every frame of every clip
// with its duration in one PNG, and a page showing the GIFs.
//
// `make previews BUDDY=<BuddyID>` compiles this file together with the app's sources (all but its `@main` entry point,
// like `make screenshots`) and writes build/previews/<buddy>/; without BUDDY it renders every buddy. It prints the
// command that opens each page.
//
// Variants: `make previews VARIANTS=<file.swift>` also compiles that file, which defines
// `enum PreviewVariants { static let clips: [(name: String, clip: AnimationClip)] }` – clips drafted with the app's
// types, e.g. alternatives of one clip – and renders them side by side into build/previews/variants/; buddies only
// when BUDDY names them.

@main
enum Previews {
    @MainActor
    static func main() throws {
        let names = CommandLine.arguments.dropFirst()
        var pages: [URL] = []
        #if VARIANTS
            pages.append(try Renderer(directory: "variants").render(PreviewVariants.clips))
        #endif
        let buddies = names.isEmpty && pages.isEmpty ? BuddyID.allCases : try names.map(buddy)
        for id in buddies {
            pages.append(try Renderer(directory: id.rawValue).render(id.buddy.allClips))
        }
        for page in pages {
            print("open -a Safari \(page.path)")
        }
    }

    static func buddy(_ name: String) throws -> BuddyID {
        guard let id = BuddyID(rawValue: name) else {
            let known = BuddyID.allCases.map(\.rawValue).joined(separator: ", ")
            throw Failure("unknown buddy '\(name)', one of: \(known)")
        }
        return id
    }
}

@MainActor
struct Renderer {
    /// Points per sprite pixel; the images have one pixel per point.
    static let scale = 8
    /// Behind every clip: a sign or an effect has to read on a dark and on a light desktop.
    static let backgrounds = [
        Color(.sRGB, red: 0x3A / 255, green: 0x40 / 255, blue: 0x4E / 255),
        Color(.sRGB, red: 0xEE / 255, green: 0xEC / 255, blue: 0xE8 / 255),
    ]

    let out: URL

    /// Starts from an empty build/previews/`directory`, so no image of a removed clip stays behind.
    init(directory: String) throws {
        out = URL(filePath: "build/previews/\(directory)", directoryHint: .isDirectory).absoluteURL
        try? FileManager.default.removeItem(at: out)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    }

    /// Writes a GIF of every clip, frames.png and index.html; returns the page.
    func render(_ clips: [(name: String, clip: AnimationClip)]) throws -> URL {
        for (name, clip) in clips {
            try ImageFiles.writeGIF(clip.frames.map(\.duration), to: out.appending(path: "\(name).gif")) { index in
                HStack(spacing: 0) {
                    ForEach(Self.backgrounds.indices, id: \.self) { background in
                        canvas(clip.frames[index].sprite).background(Self.backgrounds[background])
                    }
                }
            }
        }
        try ImageFiles.writePNG(sheet(clips), to: out.appending(path: "frames.png"))
        let figures = clips.map { name, clip in
            """
            <figure><img src="\(name).gif" style="image-rendering:pixelated">\
            <figcaption>\(name) · \(Self.milliseconds(clip.cycleDuration)) ms</figcaption></figure>
            """
        }
        let page = out.appending(path: "index.html")
        try """
        <!doctype html><meta charset="utf-8"><title>\(out.lastPathComponent)</title>
        <body style="background:#fff;font:13px -apple-system;display:flex;flex-wrap:wrap;gap:20px;padding:20px">
        \(figures.joined(separator: "\n"))
        </body>
        """.write(to: page, atomically: true, encoding: .utf8)
        return page
    }

    /// Every frame of every clip, a row per clip with its name and cycle, each frame with its duration.
    func sheet(_ clips: [(name: String, clip: AnimationClip)]) -> CGImage {
        let view = VStack(alignment: .leading, spacing: 16) {
            ForEach(clips.indices, id: \.self) { index in
                let (name, clip) = clips[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(name) · \(Self.milliseconds(clip.cycleDuration)) ms").font(
                        .system(size: 14, weight: .semibold))
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(clip.frames.indices, id: \.self) { frame in
                            VStack(spacing: 2) {
                                canvas(clip.frames[frame].sprite).background(Self.backgrounds[0])
                                Text("\(Self.milliseconds(clip.frames[frame].duration)) ms").font(.system(size: 11))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .foregroundStyle(.black)
        .background(.white)
        return ImageRenderer(content: view).cgImage!
    }

    func canvas(_ frame: SpriteFrame) -> SpriteCanvas {
        SpriteCanvas(frame: frame, gridWidth: BuddyCanvas.width, gridHeight: BuddyCanvas.height, scale: Self.scale)
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int(duration / .milliseconds(1))
    }
}
