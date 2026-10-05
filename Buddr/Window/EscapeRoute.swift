import CoreGraphics

/// Where the sheep goes when it leaves the screen: to the nearer of the left and right screen edges, until the panel is
/// fully past it, and back the same way. Neighbouring displays are deliberately ignored.
struct EscapeRoute: Equatable {
    enum Edge: Equatable {
        case left
        case right
    }

    enum Pace: Equatable {
        case run
        case walk

        /// Speed on short distances.
        var pointsPerSecond: CGFloat {
            switch self {
            case .run: 150
            case .walk: 45
            }
        }

        /// Longer distances are covered faster, so one way never takes longer than this.
        var maxDuration: Duration {
            switch self {
            case .run: .milliseconds(1200)
            case .walk: .seconds(3)
            }
        }
    }

    let edge: Edge
    /// Panel origin in its normal position, where the sheep comes back to.
    let home: CGPoint
    /// Panel origin just past the edge, with the panel completely off the screen.
    let away: CGPoint
    /// Time of one way.
    let duration: Duration

    /// `panelFrame` and `screenFrame` are in AppKit screen coordinates. On a tie the sheep goes right.
    init(panelFrame: CGRect, screenFrame: CGRect, pace: Pace = .run) {
        let distanceLeft = panelFrame.maxX - screenFrame.minX
        let distanceRight = screenFrame.maxX - panelFrame.minX
        edge = distanceLeft < distanceRight ? .left : .right
        home = panelFrame.origin
        let awayX = edge == .left ? screenFrame.minX - panelFrame.width : screenFrame.maxX
        away = CGPoint(x: awayX, y: panelFrame.minY)
        let distance = abs(awayX - panelFrame.minX)
        duration = min(pace.maxDuration, .seconds(Double(distance / pace.pointsPerSecond)))
    }

    /// Panel x after `time` (0…1) of the way from `from` to `to`, in whole steps of `step` points (one sprite pixel)
    /// so the movement keeps the pixel grid; the end point is always reached exactly. With `easeOut` the sheep slows
    /// down towards the end.
    static func x(from: CGFloat, to: CGFloat, time: Double, step: CGFloat, easeOut: Bool = false) -> CGFloat {
        guard time < 1 else { return to }
        let linear = max(0, time)
        let progress = easeOut ? 1 - (1 - linear) * (1 - linear) : linear
        let exact = (to - from) * CGFloat(progress)
        return from + (exact / step).rounded(.towardZero) * step
    }
}
