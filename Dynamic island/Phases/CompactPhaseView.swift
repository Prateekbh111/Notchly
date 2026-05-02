import SwiftUI
import DynamicIslandCore

struct CompactPhaseView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack {
            ArtworkView(data: track?.artwork)
                .frame(width: max(0, height - 8), height: max(0, height - 8))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.black.opacity(isPlaying ? 0 : 0.4))
                )
                .opacity(isPlaying ? 1 : 0.6)
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            Spacer()

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: max(0, height - 12), height: max(0, height - 12))
                .opacity(isPlaying ? 1 : 0.45)
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: height)
    }
}

struct ArtworkView: View {
    let data: Data?

    var body: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(white: 0.15)
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
