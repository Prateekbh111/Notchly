import SwiftUI

struct NotchShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var bottomRadius: CGFloat
    var topInvertedRadius: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(width, height),
                AnimatablePair(bottomRadius, topInvertedRadius)
            )
        }
        set {
            width = newValue.first.first
            height = newValue.first.second
            bottomRadius = newValue.second.first
            topInvertedRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let W = max(0, width)
        let H = max(0, height)
        let tR = max(0, topInvertedRadius)
        let bR = max(0, min(bottomRadius, min(W, H) / 2))

        // 1) Move to outer top-left shoulder corner (above pill body).
        p.move(to: CGPoint(x: -tR, y: -tR))
        // 2) Top edge across at menu-bar-bottom level.
        p.addLine(to: CGPoint(x: W + tR, y: -tR))
        // 3) Right shoulder inverse arc: from (W+tR, -tR) down-left to (W, 0).
        //    Center (W+tR, 0). Going CCW visually so arc bulges up-right
        //    OUTSIDE the silhouette — interior gets a concave bite.
        p.addArc(
            center: CGPoint(x: W + tR, y: 0),
            radius: tR,
            startAngle: .degrees(270),
            endAngle: .degrees(180),
            clockwise: true
        )
        // 4) Right side of pill body.
        p.addLine(to: CGPoint(x: W, y: H - bR))
        // 5) Bottom-right convex.
        p.addArc(
            center: CGPoint(x: W - bR, y: H - bR),
            radius: bR,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        // 6) Bottom edge.
        p.addLine(to: CGPoint(x: bR, y: H))
        // 7) Bottom-left convex.
        p.addArc(
            center: CGPoint(x: bR, y: H - bR),
            radius: bR,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        // 8) Left side of pill body.
        p.addLine(to: CGPoint(x: 0, y: 0))
        // 9) Left shoulder inverse arc: from (0, 0) up-left to (-tR, -tR).
        p.addArc(
            center: CGPoint(x: -tR, y: 0),
            radius: tR,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: true
        )
        p.closeSubpath()
        return p
    }
}
