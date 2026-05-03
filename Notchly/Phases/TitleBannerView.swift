import SwiftUI
import NotchlyCore

struct TitleBannerView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID
    let width: CGFloat
    let height: CGFloat
    let notchInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Color.clear
                    .frame(width: max(0, notchInset - 8), height: max(0, notchInset - 8))
                    .matchedGeometryEffect(id: "artwork", in: artNamespace, isSource: true)
                Spacer()
                Color.clear
                    .frame(width: max(0, notchInset - 12), height: max(0, notchInset - 12))
                    .matchedGeometryEffect(id: "eq", in: artNamespace, isSource: true)
            }
            .frame(height: notchInset)
            MarqueeView {
                HStack(alignment: .center, spacing: 4) {
                    Text(track?.title ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white).opacity(0.7)
                    Text(" . ").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white).opacity(0.2)
                    Text(track?.artist ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white).opacity(0.7)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: height)
    }
}
