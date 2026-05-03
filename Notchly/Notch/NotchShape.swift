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
        let tR = max(0, min(topInvertedRadius, H / 2))
        let bR = max(0, min(bottomRadius, min(W, H) / 2))

        // Body fills frame y=0..H. Shoulders are lateral-only extensions
        // outside frame at x=-tR..0 and x=W..W+tR, y=0..tR.

        p.move(to: CGPoint(x: -tR, y: 0))
        p.addLine(to: CGPoint(x: W + tR, y: 0))
        p.addArc(
            center: CGPoint(x: W + tR, y: tR),
            radius: tR,
            startAngle: .degrees(270),
            endAngle: .degrees(180),
            clockwise: true
        )
        p.addLine(to: CGPoint(x: W, y: H - bR))
        p.addArc(
            center: CGPoint(x: W - bR, y: H - bR),
            radius: bR,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: bR, y: H))
        p.addArc(
            center: CGPoint(x: bR, y: H - bR),
            radius: bR,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: 0, y: tR))
        p.addArc(
            center: CGPoint(x: -tR, y: tR),
            radius: tR,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: true
        )
        p.closeSubpath()
        return p
    }
}
