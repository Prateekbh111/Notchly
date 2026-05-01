import SwiftUI
import Combine
import DynamicIslandCore

struct NotchView: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let transport: TransportController
    @ObservedObject var hover: HoverTracker
    let notchHotspotWidth: CGFloat
    let notchSize: CGSize
    @Namespace private var artNamespace

    @State private var nowTick: Date = Date()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var phase: Phase {
        PhaseReducer.reduce(
            hovered: hover.isHovered,
            hasMedia: nowPlaying.hasMedia,
            recentChange: nowPlaying.recentChange(now: nowTick)
        )
    }

    private var shapeSize: CGSize {
        switch phase {
        case .idle:        return CGSize(width: notchSize.width, height: 0.1)
        case .compact:     return CGSize(width: 240, height: 38)
        case .titleBanner: return CGSize(width: 360, height: 44)
        case .expanded:    return CGSize(width: 480, height: 240)
        }
    }

    private var cornerRadius: CGFloat {
        switch phase {
        case .idle:        return 0
        case .compact:     return 19
        case .titleBanner: return 22
        case .expanded:    return 36
        }
    }

    var body: some View {
        let clipShape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack {
                    NotchBackground(cornerRadius: cornerRadius)
                    content
                        .opacity(phase == .idle ? 0 : 1)
                        .frame(width: shapeSize.width, height: shapeSize.height, alignment: .top)
                        .clipShape(clipShape)
                }
                .frame(width: shapeSize.width, height: shapeSize.height)
                .contentShape(clipShape)
                .onHover { isHovered in
                    hover.setHovered(isHovered)
                }

                Spacer(minLength: 0)
            }

            Color.clear
                .frame(width: notchHotspotWidth, height: notchSize.height + 4)
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered { hover.setHovered(true) }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.all)
        .animation(.smooth(duration: 0.48, extraBounce: 0.18), value: phase)
        .onReceive(tick) { now in nowTick = now }
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
        case .titleBanner:
            TitleBannerView(
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
