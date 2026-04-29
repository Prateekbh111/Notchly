import SwiftUI
import DynamicIslandCore

struct NotchView: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let transport: TransportController
    @ObservedObject var hover: HoverTracker
    let notchHotspotWidth: CGFloat
    @Namespace private var artNamespace

    private var phase: Phase {
        PhaseReducer.reduce(hovered: hover.isHovered, hasMedia: nowPlaying.hasMedia)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Visible card — present only when not idle. The card itself detects hover exit.
            if phase != .idle {
                VStack(spacing: 0) {
                    content
                        .background(NotchBackground(cornerRadius: 22))
                        .onHover { isHovered in
                            if !isHovered {
                                hover.setHovered(false)
                            } else {
                                hover.setHovered(true)
                            }
                        }
                    Spacer(minLength: 0)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.05, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.05, anchor: .top).combined(with: .opacity)
                ))
            }

            // Entry hotspot — small zone at the top of the panel around the physical notch.
            Color.clear
                .frame(width: notchHotspotWidth, height: 35)
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered {
                        hover.setHovered(true)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.all)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: phase)
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
