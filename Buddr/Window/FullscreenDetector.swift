import CoreGraphics
import Foundation

/// A window from the window server list (`CGWindowListCopyWindowInfo`), reduced to what fullscreen detection needs.
///
/// Owner, layer, bounds and alpha are available without the Screen Recording permission (window titles are not).
struct WindowInfo: Equatable, Sendable {
    var ownerPID: pid_t
    var ownerName: String
    var layer: Int
    /// Global display coordinates: origin at the top-left corner of the primary display, y grows down.
    var bounds: CGRect
    var alpha: Double
}

/// A display as seen by fullscreen detection.
struct DisplayInfo: Equatable, Sendable {
    /// AppKit screen coordinates (`NSScreen.frame`): origin at the bottom-left corner of the primary display.
    var frame: CGRect
    /// Global display coordinates (`CGDisplayBounds`), the same space as `WindowInfo.bounds`.
    var bounds: CGRect
    /// Top safe area inset (the camera housing on notched displays, zero elsewhere).
    var topInset: CGFloat
}

/// Decides whether the display with the sheep is covered by a fullscreen window – a native fullscreen app as well as
/// a borderless window (game, video) covering the whole display.
///
/// Finder draws the desktop icons in a window of its own on every display, but only on normal Spaces: a fullscreen
/// Space has none (measured on macOS 27, also with the menu bar and the wallpaper windows staying on screen). That
/// tells a fullscreen app apart from a zoomed window, which covers the same area on a notched display with an
/// auto-hidden Dock. When there is no desktop icon window at all (Finder not running, or its desktop switched off),
/// the window bounds alone decide.
enum FullscreenDetector {
    /// Window server layer of normal application windows, including native fullscreen ones.
    static let normalWindowLayer = 0
    /// Window server layer of Finder's desktop icon window.
    static let desktopIconLayer = Int(CGWindowLevelForKey(.desktopIconWindow))
    /// On a notched display, fullscreen windows start below the menu bar, which is a little taller than the top safe
    /// area inset (33 vs. 32 points on a 14" MacBook Pro, 39 vs. 38 at a scaled resolution).
    static let notchMenuBarAllowance: CGFloat = 8

    static func windows(from list: [[String: Any]]) -> [WindowInfo] {
        list.compactMap { entry in
            guard let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue,
                let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else { return nil }
            return WindowInfo(
                ownerPID: pid,
                ownerName: entry[kCGWindowOwnerName as String] as? String ?? "",
                layer: layer,
                bounds: bounds,
                alpha: (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1)
        }
    }

    /// The display showing the largest part of `frame` (AppKit coordinates), or `nil` if it is on no display.
    static func display(containing frame: CGRect, in displays: [DisplayInfo]) -> DisplayInfo? {
        ScreenGeometry.overlappingScreen(for: frame, in: displays.map(\.frame)).map { displays[$0] }
    }

    /// The window that makes the display count as fullscreen (the largest one when several windows cover it together),
    /// or `nil`. Only visible windows of other apps in the normal window layer count; the Dock, system overlays and
    /// the menu bar are in other layers.
    ///
    /// - Desktop icons on the display (a normal Space): only a borderless window covering the whole display, menu bar
    ///   included, is fullscreen. A zoomed window leaves the menu bar uncovered.
    /// - Desktop icons on another display only (a fullscreen Space): the windows together cover the display (an app
    ///   may draw its toolbar in a separate window, split view shows two apps). On a notched display the band with the
    ///   camera housing and the menu bar may stay uncovered.
    /// - No desktop icons anywhere: one window covers the display; on a notched display the band may stay uncovered,
    ///   so a zoomed window next to an auto-hidden Dock counts too.
    static func fullscreenWindow(
        in windows: [WindowInfo], display: DisplayInfo, excludingPID ownPID: pid_t
    ) -> WindowInfo? {
        let desktops = windows.filter { $0.layer == desktopIconLayer }
        let candidates = windows.filter { window in
            window.ownerPID != ownPID && window.layer == normalWindowLayer && window.alpha > 0
                && window.bounds.intersects(display.bounds)
        }
        let showsDesktop = desktops.contains { display.bounds.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY)) }
        if showsDesktop {
            return candidates.first { $0.bounds.contains(display.bounds) }
        }
        let required = belowNotchBand(of: display)
        if desktops.isEmpty {
            return candidates.first { $0.bounds.contains(required) }
        }
        guard covers(required, with: candidates.map(\.bounds)) else { return nil }
        return candidates.max {
            area($0.bounds.intersection(display.bounds)) < area($1.bounds.intersection(display.bounds))
        }
    }

    /// The display without the band a fullscreen window leaves uncovered on a notched display.
    private static func belowNotchBand(of display: DisplayInfo) -> CGRect {
        let uncoveredTop = display.topInset > 0 ? display.topInset + notchMenuBarAllowance : 0
        var rect = display.bounds
        rect.origin.y += uncoveredTop
        rect.size.height -= uncoveredTop
        return rect
    }

    /// Whether the union of `rects` covers `target`: the target is cut into cells along all rectangle edges, and every
    /// cell must lie in one of them.
    static func covers(_ target: CGRect, with rects: [CGRect]) -> Bool {
        let pieces = rects.map { $0.intersection(target) }.filter { !$0.isNull && !$0.isEmpty }
        guard !pieces.isEmpty else { return false }
        let xs = Set([target.minX, target.maxX] + pieces.flatMap { [$0.minX, $0.maxX] }).sorted()
        let ys = Set([target.minY, target.maxY] + pieces.flatMap { [$0.minY, $0.maxY] }).sorted()
        for (left, right) in zip(xs, xs.dropFirst()) {
            for (top, bottom) in zip(ys, ys.dropFirst()) {
                let center = CGPoint(x: (left + right) / 2, y: (top + bottom) / 2)
                guard pieces.contains(where: { $0.contains(center) }) else { return false }
            }
        }
        return true
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}

/// Turns fullscreen observations into changes: fullscreen starts right away, but ends only after it has been gone for
/// `offDelay` – during a fullscreen transition the window briefly stops covering the display.
struct FullscreenDebounce {
    static let offDelay: Duration = .milliseconds(600)

    enum Outcome: Equatable {
        case unchanged
        case changed(isFullscreen: Bool)
        /// Fullscreen seems to be gone; observe again after this delay to confirm it.
        case confirm(after: Duration)
    }

    private(set) var isFullscreen = false
    private var offSince: ContinuousClock.Instant?

    mutating func observe(_ fullscreen: Bool, at now: ContinuousClock.Instant) -> Outcome {
        if fullscreen {
            offSince = nil
            guard !isFullscreen else { return .unchanged }
            isFullscreen = true
            return .changed(isFullscreen: true)
        }
        guard isFullscreen else { return .unchanged }
        guard let offSince else {
            offSince = now
            return .confirm(after: Self.offDelay)
        }
        let gone = now - offSince
        guard gone >= Self.offDelay else { return .confirm(after: Self.offDelay - gone) }
        self.offSince = nil
        isFullscreen = false
        return .changed(isFullscreen: false)
    }
}
