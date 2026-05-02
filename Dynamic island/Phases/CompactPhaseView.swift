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
                .frame(width: max(0, height - 4), height: max(0, height - 4))
                .clipShape(Circle())
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            Spacer()

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: max(0, height - 6), height: max(0, height - 6))
        }
        .padding(.horizontal, 10)
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
