import SwiftUI

struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var topInvertedRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, topInvertedRadius) }
        set {
            bottomRadius = newValue.first
            topInvertedRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let bR = max(0, min(bottomRadius, min(w, h) / 2))
        let tR = max(0, min(topInvertedRadius, min(w, h) / 2))

        p.move(to: CGPoint(x: tR, y: 0))
        p.addLine(to: CGPoint(x: w - tR, y: 0))
        p.addArc(
            center: CGPoint(x: w - tR, y: tR),
            radius: tR,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: true
        )
        p.addLine(to: CGPoint(x: w, y: h - bR))
        p.addArc(
            center: CGPoint(x: w - bR, y: h - bR),
            radius: bR,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: bR, y: h))
        p.addArc(
            center: CGPoint(x: bR, y: h - bR),
            radius: bR,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: 0, y: tR))
        p.addArc(
            center: CGPoint(x: tR, y: tR),
            radius: tR,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: true
        )
        p.closeSubpath()
        return p
    }
}
