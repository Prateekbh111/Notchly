import SwiftUI
import DynamicIslandCore

struct NotchBackground: View {
    let cornerRadius: CGFloat
    let topCornerRadius: CGFloat

    init(cornerRadius: CGFloat, topCornerRadius: CGFloat = 28) {
        self.cornerRadius = cornerRadius
        self.topCornerRadius = topCornerRadius
    }

    var body: some View {
        NotchShape(cornerRadius: cornerRadius, topCornerRadius: topCornerRadius)
            .fill(.black.opacity(0.92))
            .overlay(
                NotchShape(cornerRadius: cornerRadius, topCornerRadius: topCornerRadius)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
    }
}
