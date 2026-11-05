import AppKit
import SwiftUI

// Renders the README images from Buddr's own code: the sprites and clips (`SheepSprites` and the others), the renderer
// (`SpriteCanvas`), the state machine (`BuddyAnimator`), the name plate (`AttentionTracker`, `NamePlateSprite`,
// `NamePlateLayout`) and the menu bar list (`AgentListView`). Nothing here draws a pixel of a buddy itself.
//
// `make screenshots` compiles this file together with the app's sources (all but its `@main` entry point, without
// DEBUG, so the list has no debug section) and runs it in the repository: the images go to docs/images. It fails
// when README.md shows an image at another width than half its pixels. The agents are made up.

@main
enum Screenshots {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let renderer = try Renderer()
        try renderer.hero()
        try renderer.namePlate()
        try renderer.menu()
    }
}

@MainActor
struct Renderer {
    let out = URL(fileURLWithPath: "docs/images", isDirectory: true)
    let readme: String

    /// Pixels per point of every image; the README shows them at half their size, so they stay sharp on Retina.
    static let pixelsPerPoint = 2
    /// Behind the buddies of the hero image. Opaque: GIF has only 1-bit transparency, the `unknown` buddy is
    /// translucent, and ImageIO writes only the changed part of a frame only when no pixel is transparent.
    static let card = Color(.sRGB, red: 0xEE / 255, green: 0xEC / 255, blue: 0xE8 / 255)
    /// A flat desktop: a gradient bands in the 256 colors of a GIF.
    static let wallpaper = Color(.sRGB, red: 0.42, green: 0.47, blue: 0.75)
    /// The plate of the sample agents; README.md quotes it in the alt text of blocked.gif.
    static let plateText = "blog · Fix CI  +1"

    init() throws {
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        readme = try String(contentsOfFile: "README.md", encoding: .utf8)
    }

    // MARK: Hero

    /// A few of the buddies, a row each.
    static let heroBuddies: [BuddyID] = [.sheep, .ufo, .corgi]
    /// The columns: what the state machine plays for each state.
    static let heroStates: [(name: String, frames: (Buddy) throws -> [AnimationFrame])] = [
        ("blocked", { play(.blocked, buddy: $0, cycles: 1).frames }),
        // `doneJump` when the state starts, then every 4th cycle, `doneHold` otherwise.
        ("done", { play(.done, buddy: $0, cycles: BuddyAnimator.doneJumpEvery).frames }),
        ("working", { play(.working, buddy: $0, cycles: 1).frames }),
        ("idle", { try idle(buddy: $0) }),
        ("sleeping", { play(.idle, buddy: $0, cycles: 1, sleepAfter: .zero).frames }),
        ("unknown", { play(.unknown, buddy: $0, cycles: 1).frames }),
    ]

    /// Every state of a few buddies side by side, with the states' names in the plate's pixel font, each looping what
    /// the state machine plays for it: hero.gif.
    func hero() throws {
        let rows = try Self.heroBuddies.map { id in
            let buddy = id.buddy
            return try Self.heroStates.map { try $0.frames(buddy) }
        }
        let scale = 4
        let total = Duration.milliseconds(4200)
        let sample = Duration.milliseconds(20)
        let tracks = rows.map { $0.map { Self.looped($0, for: total) } }
        // Sampled every 20 ms (browsers show shorter GIF delays as 100 ms), identical neighbours merged.
        var steps: [(frames: [[SpriteFrame]], duration: Duration)] = []
        for index in 0..<Int(total / sample) {
            let frames = tracks.map { $0.map { Self.frame(in: $0, at: sample * index) } }
            if steps.last?.frames == frames {
                steps[steps.count - 1].duration += sample
            } else {
                steps.append((frames, sample))
            }
        }
        try writeGIF(steps.map(\.duration), "hero.gif") { heroView(steps[$0].frames, scale: scale) }
    }

    /// A row of frames per buddy, the states' names under the last one.
    func heroView(_ rows: [[SpriteFrame]], scale: Int) -> some View {
        Grid(horizontalSpacing: CGFloat(2 * scale), verticalSpacing: CGFloat(scale)) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(rows[row].indices, id: \.self) { column in
                        buddy(rows[row][column], scale: scale)
                    }
                }
            }
            GridRow {
                ForEach(Self.heroStates.map(\.name), id: \.self) { name in
                    SpriteCanvas(sprite: PixelFont.sprite(for: name, color: SheepSprites.outline), scale: scale / 2)
                }
            }
        }
        .padding(CGFloat(3 * scale))
        .background(Self.card)
    }

    // MARK: Name plate

    /// The bottom-right corner of a screen with a blocked sheep where it starts by default and the plate that names
    /// the agent under it: blocked.gif.
    func namePlate() throws {
        var tracker = AttentionTracker()
        guard let plate = tracker.update(with: Self.snapshot, status: Self.snapshot.status),
            let label = plate.label(showing: NamePlate.Field.all)
        else { throw Failure("no name plate for the sample agents") }
        let text = NamePlateSprite.text(for: label)
        guard text == Self.plateText else {
            throw Failure("the plate reads \"\(text)\": update `plateText` and the alt text in README.md")
        }
        let frames = Self.play(.blocked, buddy: BuddyID.sheep.buddy, cycles: 1).frames
        try writeGIF(frames.map(\.duration), "blocked.gif") { screenCorner(frame: frames[$0].sprite, label: label) }
    }

    func screenCorner(frame: SpriteFrame, label: NamePlate.Label) -> some View {
        let screen = CGRect(x: 0, y: 0, width: 300, height: 200)
        let scale = BuddyPanelController.defaultScale
        let buddySize = BuddyView.size(scale: scale)
        let origin = BuddyPanelController.defaultOrigin(
            panelSize: buddySize, visibleFrame: screen, reservedBelow: NamePlateLayout.reservedHeight(buddyScale: scale)
        )
        let buddyFrame = CGRect(origin: origin, size: buddySize)
        let plateScale = NamePlateLayout.plateScale(buddyScale: scale)
        let plate = NamePlateSprite.sprite(for: label)
        let plateSize = SpriteCanvas.size(gridWidth: plate.width, gridHeight: plate.height, scale: plateScale)
        let plateFrame = NamePlateLayout.frame(
            plateSize: plateSize, buddyFrame: buddyFrame, visibleFrame: screen, plateScale: plateScale)
        // AppKit frames have y up, SwiftUI offsets y down.
        func top(_ rect: CGRect) -> CGFloat { screen.height - rect.maxY }
        return ZStack(alignment: .topLeading) {
            Self.wallpaper
            buddy(frame, scale: scale).offset(x: buddyFrame.minX, y: top(buddyFrame))
            SpriteCanvas(sprite: plate, scale: plateScale).offset(x: plateFrame.minX, y: top(plateFrame))
        }
        .frame(width: screen.width, height: screen.height)
    }

    // MARK: Menu bar list

    /// The menu bar list in both appearances: menu-light.png, menu-dark.png. A real `NSHostingView` in an off-screen
    /// window, drawn with `cacheDisplay` – `ImageRenderer` leaves the content of a `ScrollView` out.
    func menu() throws {
        let store = SnapshotStore()
        store.snapshot = Self.snapshot
        // A volatile suite: the defaults of every setting, nothing read from or written to the user's.
        let suite = "cz.jsyrovy.buddr.screenshots"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let list = AgentListView(
            store: store, preferences: Preferences(defaults: defaults), hiding: BuddyHiding(), onOpen: {})
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let content =
                list
                // Accent-colored checkboxes, as in the open (key) menu bar window.
                .environment(\.controlActiveState, .key)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            let hosting = NSHostingView(rootView: content)
            let window = NSWindow(
                contentRect: NSRect(x: -10000, y: -10000, width: 360, height: 600), styleMask: [.borderless],
                backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView = hosting
            // The list measures its content first; let SwiftUI lay out and the AppKit controls appear.
            for _ in 0..<5 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                hosting.layoutSubtreeIfNeeded()
                window.setContentSize(hosting.fittingSize)
            }
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                throw Failure("can't draw the menu bar list")
            }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try writePNG(bitmap.cgImage!, "menu-\(name).png")
            window.close()
        }
    }

    // MARK: Sample agents

    /// The agents behind the name plate and the menu bar list.
    static let snapshot: HerdrSnapshot = {
        let local = AgentSource.herdr(.localSession("default"))
        let core = AgentSource.core(machine: nil)
        let devel = AgentSource.herdr(.machine(id: "3f2a", label: "devel"))
        let buildBox = AgentSource.core(machine: "build-box")
        func agent(
            _ source: AgentSource, _ workspace: String, _ number: Int?, _ pane: String, _ kind: String,
            _ status: AgentStatus, _ title: String, order: UInt64? = nil
        ) -> AgentRecord {
            AgentRecord(
                source: source, workspaceID: workspace, workspace: workspace, workspaceNumber: number, paneID: pane,
                agent: kind, status: status, title: title, cwd: "/Users/me/code/\(workspace)", statusOrder: order)
        }
        return HerdrSnapshot(
            agents: [
                agent(local, "buddr", 1, "p1", "claude", .working, "Add README screenshots"),
                agent(local, "buddr", 1, "p2", "codex", .idle, "Review the changelog"),
                // The newest of the blocked agents: the plate names it.
                agent(local, "blog", 2, "p3", "claude", .blocked, "Fix CI", order: 42),
                agent(core, "notes", nil, "t3", "claude-code", .done, "Summarize the meeting"),
                agent(core, "notes", nil, "t5", "claude-code", .idle, "Draft the release notes"),
                agent(devel, "parser", 1, "p7", "claude", .blocked, "Handle empty input", order: 10),
                agent(devel, "api", 2, "p8", "claude", .working, "Migrate to Postgres 18"),
                agent(devel, "api", 2, "p9", "codex", .idle, "Rate limiter"),
                agent(devel, "api", 2, "p10", "codex", .idle, "Flaky test"),
                agent(devel, "api", 2, "p11", "claude", .idle, "OpenAPI spec"),
                agent(devel, "api", 2, "p12", "claude", .idle, "Docker image"),
            ],
            failures: [SourceFailure(source: buildBox, message: "unreachable: connection timed out")],
            sources: [local, core, devel, buildBox])
    }()

    // MARK: Clips

    /// The frames and clips the state machine plays for `status` in its first `cycles` clips.
    static func play(
        _ status: AgentStatus, buddy: Buddy, cycles: Int, seed: UInt64 = 1,
        sleepAfter: Duration = BuddyAnimator.defaultSleepAfter
    ) -> (frames: [AnimationFrame], clips: [ClipID]) {
        var animator = BuddyAnimator(buddy: buddy, status: status, sleepAfter: sleepAfter, seed: seed)
        var frames: [AnimationFrame] = []
        var clips: [ClipID] = []
        for _ in 0..<cycles {
            clips.append(animator.clipID)
            repeat {
                frames.append(animator.frame)
                animator.advance()
            } while animator.frameIndex != 0
        }
        return (frames, clips)
    }

    /// Four idle clips that start at rest and include a blink and a look around.
    static func idle(buddy: Buddy) throws -> [AnimationFrame] {
        let run = (UInt64(1)...1000).lazy.map { play(.idle, buddy: buddy, cycles: 4, seed: $0) }.first {
            $0.clips.first == .idleRest && $0.clips.contains(.idleBlink) && $0.clips.contains(.idleLook)
        }
        guard let run else { throw Failure("no idle seed with a rest, a blink and a look") }
        return run.frames
    }

    /// Whole loops of `frames` for `total`; the last picture is held for the rest.
    static func looped(_ frames: [AnimationFrame], for total: Duration) -> [AnimationFrame] {
        let length = AnimationClip(frames).cycleDuration
        var result = Array(repeating: frames, count: max(1, Int(total / length))).flatMap { $0 }
        let rest = total - AnimationClip(result).cycleDuration
        if rest > .zero, let last = result.popLast() {
            result.append(AnimationFrame(sprite: last.sprite, duration: last.duration + rest))
        }
        return result
    }

    static func frame(in track: [AnimationFrame], at time: Duration) -> SpriteFrame {
        var time = time
        for frame in track {
            if time < frame.duration { return frame.sprite }
            time -= frame.duration
        }
        return track[track.count - 1].sprite
    }

    // MARK: Drawing and files

    func buddy(_ frame: SpriteFrame, scale: Int) -> SpriteCanvas {
        SpriteCanvas(
            frame: frame, gridWidth: BuddyCanvas.width, gridHeight: BuddyCanvas.height, scale: scale)
    }

    func writePNG(_ image: CGImage, _ name: String) throws {
        try ImageFiles.writePNG(image, to: out.appending(path: name))
        try checkReadme(name, width: image.width)
    }

    /// An animated GIF that loops forever: `image(i)` shown for `durations[i]`.
    func writeGIF<Content: View>(_ durations: [Duration], _ name: String, image: (Int) -> Content) throws {
        let width = try ImageFiles.writeGIF(
            durations, to: out.appending(path: name), scale: Self.pixelsPerPoint, image: image)
        try checkReadme(name, width: width)
    }

    /// Checks that README.md shows the image written as `name`, `width` pixels wide, at half its pixel width.
    func checkReadme(_ name: String, width pixels: Int) throws {
        let width = pixels / Self.pixelsPerPoint
        let source = "src=\"docs/images/\(name)\""
        if readme.contains(source), !readme.contains("\(source) width=\"\(width)\"") {
            throw Failure("README.md should show \(name) with width=\"\(width)\"")
        }
        print("docs/images/\(name)")
    }
}
