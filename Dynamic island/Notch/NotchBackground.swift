import SwiftUI
import AppKit

struct NotchBackground: View {
    let bottomCornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.bottomCornerRadius = cornerRadius
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: bottomCornerRadius,
            bottomTrailingRadius: bottomCornerRadius,
            topTrailingRadius: 0,
            style: .continuous
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
