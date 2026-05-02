import SwiftUI
import DynamicIslandCore

struct TitleBannerView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID
    let width: CGFloat
    let height: CGFloat
    let notchInset: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: track?.artwork)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.black.opacity(isPlaying ? 0 : 0.4))
                )
                .opacity(isPlaying ? 1 : 0.6)
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            VStack(alignment: .leading, spacing: 1) {
                Text(track?.title ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track?.artist ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: 18, height: 18)
                .opacity(isPlaying ? 1 : 0.45)
        }
        .padding(.top, notchInset)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(width: width, height: height)
    }
}
