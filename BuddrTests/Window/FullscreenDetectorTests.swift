import CoreGraphics
import Foundation
import Testing

@testable import Buddr

struct FullscreenDetectorTests {
    /// A 1512×982 built-in display with a notch, and a 1920×1080 external display to its right.
    private static let builtIn = DisplayInfo(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        bounds: CGRect(x: 0, y: 0, width: 1512, height: 982), topInset: 32)
    private static let external = DisplayInfo(
        frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
        bounds: CGRect(x: 1512, y: -98, width: 1920, height: 1080), topInset: 0)
    private static let ownPID: pid_t = 100

    private static func window(_ bounds: CGRect, pid: pid_t = 200, layer: Int = 0, alpha: Double = 1) -> WindowInfo {
        WindowInfo(ownerPID: pid, ownerName: "App", layer: layer, bounds: bounds, alpha: alpha)
    }

    private static func fullscreenWindow(_ windows: [WindowInfo], on display: DisplayInfo) -> WindowInfo? {
        FullscreenDetector.fullscreenWindow(in: windows, display: display, excludingPID: ownPID)
    }

    @Test func parsesTheWindowServerList() {
        let list: [[String: Any]] = [
            [
                kCGWindowOwnerPID as String: NSNumber(value: 42),
                kCGWindowOwnerName as String: "Safari",
                kCGWindowLayer as String: NSNumber(value: 0),
                kCGWindowBounds as String: CGRect(x: 10, y: 20, width: 300, height: 400).dictionaryRepresentation,
                kCGWindowAlpha as String: NSNumber(value: 0.5),
            ],
            // Owner name and alpha are optional.
            [
                kCGWindowOwnerPID as String: NSNumber(value: 43),
                kCGWindowLayer as String: NSNumber(value: 25),
                kCGWindowBounds as String: CGRect(x: 0, y: 0, width: 1, height: 2).dictionaryRepresentation,
            ],
            // Entries without bounds are skipped.
            [kCGWindowOwnerPID as String: NSNumber(value: 44), kCGWindowLayer as String: NSNumber(value: 0)],
        ]
        #expect(
            FullscreenDetector.windows(from: list) == [
                WindowInfo(
                    ownerPID: 42, ownerName: "Safari", layer: 0, bounds: CGRect(x: 10, y: 20, width: 300, height: 400),
                    alpha: 0.5),
                WindowInfo(
                    ownerPID: 43, ownerName: "", layer: 25, bounds: CGRect(x: 0, y: 0, width: 1, height: 2), alpha: 1),
            ])
    }

    @Test func picksTheDisplayShowingMostOfThePanel() {
        let displays = [Self.builtIn, Self.external]
        let mostlyOnBuiltIn = CGRect(x: 1400, y: 100, width: 192, height: 192)
        let mostlyOnExternal = CGRect(x: 1480, y: 100, width: 192, height: 192)
        #expect(FullscreenDetector.display(containing: mostlyOnBuiltIn, in: displays) == Self.builtIn)
        #expect(FullscreenDetector.display(containing: mostlyOnExternal, in: displays) == Self.external)
        #expect(
            FullscreenDetector.display(containing: CGRect(x: -500, y: 0, width: 100, height: 100), in: displays) == nil)
    }

    @Test func windowCoveringTheWholeDisplayIsFullscreen() {
        let window = Self.window(Self.external.bounds)
        #expect(Self.fullscreenWindow([window], on: Self.external) == window)
    }

    @Test func fullscreenWindowBelowTheMenuBarOfANotchedDisplayCounts() {
        // Measured on a 14" MacBook Pro: the menu bar is 33 points tall, the safe area inset 32.
        let window = Self.window(CGRect(x: 0, y: 33, width: 1512, height: 949))
        #expect(Self.fullscreenWindow([window], on: Self.builtIn) == window)
    }

    @Test func zoomedWindowNextToTheDockOfANotchedDisplayDoesNotCount() {
        let zoomed = Self.window(CGRect(x: 52, y: 33, width: 1460, height: 949))
        #expect(Self.fullscreenWindow([zoomed], on: Self.builtIn) == nil)
    }

    @Test func zoomedWindowBelowTheMenuBarDoesNotCount() {
        let zoomed = Self.window(CGRect(x: 1512, y: -73, width: 1920, height: 1055))
        #expect(Self.fullscreenWindow([zoomed], on: Self.external) == nil)
    }

    @Test func fullscreenWindowOnAnotherDisplayDoesNotCount() {
        #expect(Self.fullscreenWindow([Self.window(Self.external.bounds)], on: Self.builtIn) == nil)
    }

    @Test func ownTransparentAndOverlayWindowsDoNotCount() {
        let own = Self.window(Self.external.bounds, pid: Self.ownPID)
        let transparent = Self.window(Self.external.bounds, alpha: 0)
        let overlay = Self.window(Self.external.bounds, layer: 20)
        #expect(Self.fullscreenWindow([own, transparent, overlay], on: Self.external) == nil)
    }

    // MARK: Finder's desktop icon window

    private static func desktop(on display: DisplayInfo) -> WindowInfo {
        WindowInfo(
            ownerPID: 300, ownerName: "Finder", layer: FullscreenDetector.desktopIconLayer, bounds: display.bounds,
            alpha: 1)
    }

    @Test func zoomedWindowOnANormalSpaceOfANotchedDisplayDoesNotCount() {
        // Measured at a scaled resolution with an auto-hidden Dock: the menu bar is 39 points tall, the inset 38.
        let display = DisplayInfo(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            bounds: CGRect(x: 0, y: 0, width: 1800, height: 1169), topInset: 38)
        let zoomed = Self.window(CGRect(x: 0, y: 39, width: 1800, height: 1130))
        #expect(Self.fullscreenWindow([zoomed, Self.desktop(on: display)], on: display) == nil)
        // Without the desktop icon window, the bounds can't tell it from a fullscreen app.
        #expect(Self.fullscreenWindow([zoomed], on: display) == zoomed)
    }

    @Test func borderlessWindowCoveringANormalSpaceCounts() {
        let borderless = Self.window(Self.builtIn.bounds)
        #expect(Self.fullscreenWindow([borderless, Self.desktop(on: Self.builtIn)], on: Self.builtIn) == borderless)
    }

    @Test func desktopOfAnotherDisplayDoesNotMakeThisOneNormal() {
        let zoomed = Self.window(CGRect(x: 0, y: 33, width: 1512, height: 949))
        #expect(Self.fullscreenWindow([zoomed, Self.desktop(on: Self.builtIn)], on: Self.builtIn) == nil)
        #expect(Self.fullscreenWindow([zoomed, Self.desktop(on: Self.external)], on: Self.builtIn) == zoomed)
    }

    @Test func fullscreenAppMadeOfSeveralWindowsCounts() {
        // Chrome in fullscreen with its toolbar shown: tab strip and toolbar are windows of their own above the page.
        let tabs = Self.window(CGRect(x: 0, y: 33, width: 1512, height: 41))
        let toolbar = Self.window(CGRect(x: 0, y: 74, width: 1512, height: 46))
        let page = Self.window(CGRect(x: 0, y: 120, width: 1512, height: 862))
        let windows = [tabs, toolbar, page, Self.desktop(on: Self.external)]
        #expect(Self.fullscreenWindow(windows, on: Self.builtIn) == page)
        // Without the desktop signal, one window has to cover the display.
        #expect(Self.fullscreenWindow([tabs, toolbar, page], on: Self.builtIn) == nil)
    }

    @Test func splitViewOfTwoAppsCounts() {
        let left = Self.window(CGRect(x: 1512, y: -98, width: 960, height: 1080), pid: 201)
        let right = Self.window(CGRect(x: 2472, y: -98, width: 960, height: 1080), pid: 202)
        #expect(Self.fullscreenWindow([left, right, Self.desktop(on: Self.builtIn)], on: Self.external) != nil)
    }

    @Test func spaceWithoutDesktopIconsNeedsCoveringWindows() {
        // During a Space transition the desktop icons are gone before the fullscreen window has grown.
        let shrunk = Self.window(CGRect(x: 100, y: 100, width: 1312, height: 782))
        let own = Self.window(Self.builtIn.bounds, pid: Self.ownPID)
        let overlay = Self.window(Self.builtIn.bounds, layer: 20)
        let windows = [shrunk, own, overlay, Self.desktop(on: Self.external)]
        #expect(Self.fullscreenWindow(windows, on: Self.builtIn) == nil)
        #expect(Self.fullscreenWindow([Self.desktop(on: Self.external)], on: Self.builtIn) == nil)
    }

    @Test func coverageOfTheUnionOfRectangles() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        let top = CGRect(x: -10, y: -10, width: 120, height: 60)
        let bottom = CGRect(x: 0, y: 40, width: 100, height: 60)
        let bottomLeft = CGRect(x: 0, y: 50, width: 60, height: 50)
        let bottomRight = CGRect(x: 70, y: 50, width: 30, height: 50)
        #expect(FullscreenDetector.covers(target, with: [top, bottom]))
        #expect(!FullscreenDetector.covers(target, with: [top, bottomLeft, bottomRight]))
        #expect(!FullscreenDetector.covers(target, with: [top]))
        #expect(!FullscreenDetector.covers(target, with: [CGRect(x: 200, y: 200, width: 10, height: 10)]))
        #expect(!FullscreenDetector.covers(target, with: []))
    }
}

struct FullscreenDebounceTests {
    private static let start = ContinuousClock.now

    private static func at(_ milliseconds: Int) -> ContinuousClock.Instant {
        start + .milliseconds(milliseconds)
    }

    @Test func fullscreenStartsRightAway() {
        var debounce = FullscreenDebounce()
        #expect(debounce.observe(false, at: Self.at(0)) == .unchanged)
        #expect(debounce.observe(true, at: Self.at(100)) == .changed(isFullscreen: true))
        #expect(debounce.observe(true, at: Self.at(200)) == .unchanged)
        #expect(debounce.isFullscreen)
    }

    @Test func fullscreenEndsOnlyAfterItHasBeenGoneForTheDelay() {
        var debounce = FullscreenDebounce()
        _ = debounce.observe(true, at: Self.at(0))
        #expect(debounce.observe(false, at: Self.at(1_000)) == .confirm(after: .milliseconds(600)))
        #expect(debounce.observe(false, at: Self.at(1_250)) == .confirm(after: .milliseconds(350)))
        #expect(debounce.isFullscreen)
        #expect(debounce.observe(false, at: Self.at(1_600)) == .changed(isFullscreen: false))
        #expect(!debounce.isFullscreen)
        #expect(debounce.observe(false, at: Self.at(2_000)) == .unchanged)
    }

    @Test func briefGapDuringATransitionIsIgnored() {
        var debounce = FullscreenDebounce()
        _ = debounce.observe(true, at: Self.at(0))
        _ = debounce.observe(false, at: Self.at(250))
        #expect(debounce.observe(true, at: Self.at(500)) == .unchanged)
        // The gap starts over.
        #expect(debounce.observe(false, at: Self.at(1_000)) == .confirm(after: .milliseconds(600)))
        #expect(debounce.isFullscreen)
    }
}
