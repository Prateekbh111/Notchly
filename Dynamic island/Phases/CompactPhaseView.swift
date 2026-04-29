import SwiftUI
import DynamicIslandCore

struct CompactPhaseView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID

    var body: some View {
        HStack {
            ArtworkView(data: track?.artwork)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            Spacer()

            EQBars(active: isPlaying)
                .frame(width: 18, height: 18)
        }
        .padding(.horizontal, 14)
        .frame(width: 280, height: 30)
    }
}

private struct EQBars: View {
    let active: Bool
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 2, height: heightForBar(i))
            }
        }
        .onAppear {
            guard active else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                phase = .pi
            }
        }
    }

    private func heightForBar(_ i: Int) -> CGFloat {
        let base: CGFloat = active ? CGFloat(6 + (i * 2) % 8) : 4
        return base
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
