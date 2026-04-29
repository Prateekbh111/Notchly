import SwiftUI
import DynamicIslandCore

struct NotchView: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let transport: TransportController
    @ObservedObject var hover: HoverTracker
    let notchHotspotWidth: CGFloat
    let notchSize: CGSize
    @Namespace private var artNamespace

    private var phase: Phase {
        PhaseReducer.reduce(hovered: hover.isHovered, hasMedia: nowPlaying.hasMedia)
    }

    private var shapeSize: CGSize {
        switch phase {
        case .idle:
            return CGSize(width: notchSize.width, height: 0.1)
        case .compact:
            return CGSize(width: 200, height: 30)
        case .expanded:
            return CGSize(width: 380, height: 180)
        }
    }

    private var cornerRadii: (top: CGFloat, bottom: CGFloat) {
        switch phase {
        case .idle: return (0, 0)
        case .compact: return (4, 8)
        case .expanded: return (8, 32)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack {
                    NotchBackground(
                        cornerRadius: cornerRadii.bottom,
                        topCornerRadius: cornerRadii.top
                    )
                    content
                        .opacity(phase == .idle ? 0 : 1)
                }
                .frame(width: shapeSize.width, height: shapeSize.height)

                Spacer(minLength: 0)
            }
            .onHover { isHovered in
                if isHovered {
                    hover.setHovered(true)
                } else {
                    hover.setHovered(false)
                }
            }

            // Entry hotspot — small zone at top covering the physical notch + small padding.
            Color.clear
                .frame(width: notchHotspotWidth, height: notchSize.height + 4)
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered {
                        hover.setHovered(true)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.all)
        .animation(.spring(response: 0.42, dampingFraction: 0.74), value: phase)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .compact:
            CompactPhaseView(
                track: nowPlaying.snapshot.track,
                isPlaying: nowPlaying.snapshot.isPlaying,
                artNamespace: artNamespace
            )
            .transition(.opacity)
        case .expanded:
            ExpandedPhaseView(
                snapshot: nowPlaying.snapshot,
                transport: transport,
                artNamespace: artNamespace
            )
            .transition(.opacity)
        }
    }
}
