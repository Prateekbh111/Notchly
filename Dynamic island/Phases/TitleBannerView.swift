import SwiftUI
import DynamicIslandCore

struct TitleBannerView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(data: track?.artwork)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(track?.title ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track?.artist ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: 22, height: 22)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: width, height: height)
    }
}
