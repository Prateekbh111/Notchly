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
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
    }
}
