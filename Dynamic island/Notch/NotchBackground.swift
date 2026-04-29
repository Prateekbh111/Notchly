import SwiftUI
import DynamicIslandCore

struct NotchBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        NotchShape(cornerRadius: cornerRadius)
            .fill(.black.opacity(0.92))
            .overlay(
                NotchShape(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
    }
}
