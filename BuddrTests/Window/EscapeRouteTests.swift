import CoreGraphics
import Testing

@testable import Buddr

struct EscapeRouteTests {
    private static let screen = CGRect(x: 0, y: 0, width: 1512, height: 949)
    private static let size = CGSize(width: 132, height: 120)

    private static func route(x: CGFloat) -> EscapeRoute {
        EscapeRoute(panelFrame: CGRect(origin: CGPoint(x: x, y: 24), size: size), screenFrame: screen)
    }

    @Test func runsToTheNearerEdgeUntilThePanelIsOffTheScreen() {
        let right = Self.route(x: 1356)
        #expect(right.edge == .right)
        #expect(right.home == CGPoint(x: 1356, y: 24))
        #expect(right.away == CGPoint(x: 1512, y: 24))

        let left = Self.route(x: 100)
        #expect(left.edge == .left)
        #expect(left.away == CGPoint(x: -132, y: 24))
    }

    @Test func runsRightOnATie() {
        #expect(Self.route(x: (1512 - 132) / 2).edge == .right)
    }

    @Test func respectsTheScreenOrigin() {
        let external = CGRect(x: -531, y: 982, width: 2560, height: 1440)
        let route = EscapeRoute(
            panelFrame: CGRect(origin: CGPoint(x: -400, y: 1000), size: Self.size), screenFrame: external)
        #expect(route.edge == .left)
        #expect(route.away == CGPoint(x: -663, y: 1000))
    }

    @Test func shortDistancesAreRunAtConstantSpeedLongOnesInLimitedTime() {
        // From the default corner: 24 points margin plus the panel width.
        #expect(Self.route(x: 1356).duration == .seconds(156.0 / 150))
        #expect(Self.route(x: 700).duration == EscapeRoute.maxDuration)
    }

    @Test func movesInWholeSpritePixelsAndReachesTheEnd() {
        #expect(EscapeRoute.x(from: 100, to: 200, time: 0, step: 6) == 100)
        #expect(EscapeRoute.x(from: 100, to: 200, time: 0.1, step: 6) == 106)
        #expect(EscapeRoute.x(from: 100, to: 200, time: 0.5, step: 6) == 148)
        #expect(EscapeRoute.x(from: 200, to: 100, time: 0.5, step: 6) == 152)
        #expect(EscapeRoute.x(from: 100, to: 200, time: 0.99, step: 6) == 196)
        #expect(EscapeRoute.x(from: 100, to: 200, time: 1, step: 6) == 200)
    }

    @Test func easeOutSlowsDownTowardsTheEnd() {
        #expect(EscapeRoute.x(from: 0, to: 600, time: 0.5, step: 6, easeOut: true) == 450)
        #expect(EscapeRoute.x(from: 0, to: 600, time: 0.9, step: 6, easeOut: true) == 594)
        #expect(EscapeRoute.x(from: 0, to: 600, time: 1, step: 6, easeOut: true) == 600)
    }
}
