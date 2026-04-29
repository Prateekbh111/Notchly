import SwiftUI
import DynamicIslandCore

struct ExpandedPhaseView: View {
    let snapshot: NowPlayingSnapshot
    let transport: TransportController
    let artNamespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ArtworkView(data: snapshot.track?.artwork)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .matchedGeometryEffect(id: "artwork", in: artNamespace)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.track?.title ?? "Not Playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if let artist = snapshot.track?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: "waveform")
                    .foregroundStyle(.white.opacity(0.7))
            }

            ScrubberView(elapsed: snapshot.elapsed, duration: snapshot.track?.duration ?? 0)

            HStack(spacing: 24) {
                Button(action: { transport.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                }
                Button(action: { transport.previous() }) {
                    Image(systemName: "backward.fill")
                }
                Button(action: { transport.playPause() }) {
                    Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                }
                Button(action: { transport.next() }) {
                    Image(systemName: "forward.fill")
                }
                Button(action: {}) {
                    Image(systemName: "laptopcomputer")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 360)
    }
}

private struct ScrubberView: View {
    let elapsed: TimeInterval
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(.white).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)

            HStack {
                Text(format(elapsed))
                Spacer()
                Text("-" + format(max(0, duration - elapsed)))
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, elapsed / duration)))
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
