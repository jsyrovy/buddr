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
enum FullscreenDetector {
    /// Window server layer of normal application windows, including native fullscreen ones.
    static let normalWindowLayer = 0
    /// On a notched display, fullscreen windows start below the menu bar, which is a little taller than the top safe
    /// area inset (33 vs. 32 points on a 14" MacBook Pro).
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

    /// The window that makes the display count as fullscreen: a visible window of another app in the normal window
    /// layer that covers the whole display. Windows in other layers (the Dock, system overlays) don't count. On a
    /// notched display the band with the camera housing and the menu bar may stay uncovered. A zoomed window doesn't
    /// count: it leaves the menu bar uncovered on a display without a notch, and the Dock on a notched one.
    static func fullscreenWindow(
        in windows: [WindowInfo], display: DisplayInfo, excludingPID ownPID: pid_t
    ) -> WindowInfo? {
        let uncoveredTop = display.topInset > 0 ? display.topInset + notchMenuBarAllowance : 0
        var required = display.bounds
        required.origin.y += uncoveredTop
        required.size.height -= uncoveredTop
        return windows.first { window in
            window.ownerPID != ownPID && window.layer == normalWindowLayer && window.alpha > 0
                && window.bounds.contains(required)
        }
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
