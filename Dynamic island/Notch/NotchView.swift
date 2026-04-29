import SwiftUI
import DynamicIslandCore

struct NotchView: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let transport: TransportController
    @ObservedObject var hover: HoverTracker
    @Namespace private var artNamespace

    private var phase: Phase {
        PhaseReducer.reduce(hovered: hover.isHovered, hasMedia: nowPlaying.hasMedia)
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .background(NotchShape(cornerRadius: 18).fill(.black))
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: phase)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            IdlePhaseView()
        case .compact:
            CompactPhaseView(
                track: nowPlaying.snapshot.track,
                isPlaying: nowPlaying.snapshot.isPlaying,
                artNamespace: artNamespace
            )
        case .expanded:
            ExpandedPhaseView(
                snapshot: nowPlaying.snapshot,
                transport: transport,
                artNamespace: artNamespace
            )
        }
    }
}
