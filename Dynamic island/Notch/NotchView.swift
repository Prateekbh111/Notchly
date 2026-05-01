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
        case .compact:     return CGSize(width: 200, height: 32)
        case .titleBanner: return CGSize(width: 420, height: 40)
        case .expanded:    return CGSize(width: 380, height: 180)
        }
    }

    private var cornerRadii: (top: CGFloat, bottom: CGFloat) {
        switch phase {
        case .idle:        return (0, 0)
        case .compact:     return (0, 12)
        case .titleBanner: return (0, 20)
        case .expanded:    return (0, 32)
        }
    }

    var body: some View {
        let clipShape = UnevenRoundedRectangle(
            topLeadingRadius: cornerRadii.top,
            bottomLeadingRadius: cornerRadii.bottom,
            bottomTrailingRadius: cornerRadii.bottom,
            topTrailingRadius: cornerRadii.top,
            style: .continuous
        )
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack {
                    NotchBackground(
                        cornerRadius: cornerRadii.bottom,
                        topCornerRadius: cornerRadii.top
                    )
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
        .animation(.interpolatingSpring(stiffness: 220, damping: 22), value: phase)
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
