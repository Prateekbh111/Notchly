import SwiftUI
import AppKit

struct NotchBackground: View {
    let width: CGFloat
    let height: CGFloat
    let bottomRadius: CGFloat
    let topInvertedRadius: CGFloat

    var body: some View {
        let shape = NotchShape(
            width: width,
            height: height,
            bottomRadius: bottomRadius,
            topInvertedRadius: topInvertedRadius
        )
        shape
            .fill(.black)
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .blur(radius: 10)
                    .padding(-10)
            }
    }
}
