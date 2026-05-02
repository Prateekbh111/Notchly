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
        VStack(){
            HStack(spacing: 12) {
                ArtworkView(data: track?.artwork)
                    .frame(width: max(0, notchInset - 8), height: max(0, notchInset - 8))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.black.opacity(isPlaying ? 0 : 0.4))
                    )
                    .opacity(isPlaying ? 1 : 0.6)
                    .matchedGeometryEffect(id: "artwork", in: artNamespace)
                Spacer()
                EQGlyphView(isPlaying: isPlaying)
                    .frame(width: max(0, notchInset - 12), height: max(0, notchInset - 12))
                    .opacity(isPlaying ? 1 : 0.45)
            }
            HStack(alignment: .center) {
                Text(track?.title ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(" . ").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track?.artist ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: height)
    }
}
