import SwiftUI
import AppKit

struct NotchBackground: View {
    let bottomCornerRadius: CGFloat
    let topInvertedRadius: CGFloat

    init(cornerRadius: CGFloat, topCornerRadius: CGFloat = 10) {
        self.bottomCornerRadius = cornerRadius
        self.topInvertedRadius = topCornerRadius
    }

    var body: some View {
        let shape = NotchShape(
            bottomRadius: bottomCornerRadius,
            topInvertedRadius: topInvertedRadius
        )
        shape
            .fill(.black)
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .blur(radius: 10)
                    .padding(-10)
            }
    }
}
