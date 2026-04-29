import SwiftUI
import AppKit
import DynamicIslandCore

struct NotchBackground: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat

    init(cornerRadius: CGFloat, topCornerRadius: CGFloat = 8) {
        self.bottomCornerRadius = cornerRadius
        self.topCornerRadius = topCornerRadius
    }

    var body: some View {
        NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
            .fill(.black.opacity(0.92))
            .overlay(
                NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
    }
}
