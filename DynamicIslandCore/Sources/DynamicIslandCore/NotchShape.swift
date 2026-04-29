import SwiftUI

public struct NotchShape: Shape, Sendable {
    public var cornerRadius: CGFloat
    public var topCornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 22, topCornerRadius: CGFloat = 10) {
        self.cornerRadius = cornerRadius
        self.topCornerRadius = topCornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2, rect.width / 2)
        let tr = min(topCornerRadius, r, rect.width / 2)

        // Top edge — starts inset by tr, ends inset by tr
        path.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))

        // Concave top-right corner: curve OUT-and-DOWN with control at the outer corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + tr),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // Right side down to bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))

        // Convex bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))

        // Convex bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left side up
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))

        // Concave top-left corner: curve OUT-and-UP with control at the outer corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
