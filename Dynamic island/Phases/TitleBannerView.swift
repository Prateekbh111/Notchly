import SwiftUI
import DynamicIslandCore

struct TitleBannerView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(data: track?.artwork)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: width, height: height)
    }
}
