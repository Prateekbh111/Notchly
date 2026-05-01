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
                .frame(width: height - 12, height: height - 12)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            Spacer()

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: 18, height: height - 16)
        }
        .padding(.horizontal, 14)
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
