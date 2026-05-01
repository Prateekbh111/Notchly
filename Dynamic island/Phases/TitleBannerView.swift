import SwiftUI
import DynamicIslandCore

struct TitleBannerView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(data: track?.artwork)
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            MarqueeText(text: bannerText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 12)
        .frame(width: 420, height: 40)
    }

    private var bannerText: String {
        guard let track else { return "" }
        if track.artist.isEmpty { return track.title }
        return "\(track.title) — \(track.artist)"
    }
}
