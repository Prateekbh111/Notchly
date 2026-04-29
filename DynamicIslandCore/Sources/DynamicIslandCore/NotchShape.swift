import SwiftUI

public struct NotchShape: Shape, Sendable {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public init(topCornerRadius: CGFloat = 8, bottomCornerRadius: CGFloat = 32) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    // Backward compat for callers passing a single cornerRadius
    public init(cornerRadius: CGFloat = 32, topCornerRadius: CGFloat? = nil) {
        self.bottomCornerRadius = cornerRadius
        self.topCornerRadius = topCornerRadius ?? min(8, cornerRadius)
    }

    public func path(in rect: CGRect) -> Path {
        let tr = min(topCornerRadius, rect.height / 2, rect.width / 2)
        let br = min(bottomCornerRadius, rect.height / 2, rect.width / 2)
        var path = Path()

        // Top-left
        path.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        // Top-right convex corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + tr),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        // Right side
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        // Bottom-right convex corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - br, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        // Bottom-left convex corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - br),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        // Left side
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        // Top-left convex corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
