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

    private struct Geometry {
        var width: CGFloat
        var height: CGFloat
        var bottomRadius: CGFloat
        var topInvertedRadius: CGFloat
    }

    private var geometry: Geometry {
        switch phase {
        case .idle:
            return Geometry(width: notchSize.width, height: 0.1, bottomRadius: 0, topInvertedRadius: 0)
        case .compact:
            return Geometry(width: 257, height: notchSize.height, bottomRadius: 12, topInvertedRadius: 6)
        case .titleBanner:
            return Geometry(width: 276, height: 74, bottomRadius: 22, topInvertedRadius: 6)
        case .expanded:
            return Geometry(width: 345, height: 174, bottomRadius: 44, topInvertedRadius: 16)
        }
    }

    var body: some View {
        let g = geometry
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack {
                    NotchBackground(
                        width: g.width,
                        height: g.height,
                        bottomRadius: g.bottomRadius,
                        topInvertedRadius: g.topInvertedRadius
                    )
                    content
                        .opacity(phase == .idle ? 0 : 1)
                        .frame(width: g.width, height: g.height, alignment: .top)
                        .clipShape(
                            NotchShape(
                                width: g.width,
                                height: g.height,
                                bottomRadius: g.bottomRadius,
                                topInvertedRadius: 0
                            )
                        )
                }
                .frame(width: g.width, height: g.height)
                .contentShape(
                    NotchShape(
                        width: g.width,
                        height: g.height,
                        bottomRadius: g.bottomRadius,
                        topInvertedRadius: g.topInvertedRadius
                    )
                )
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
        .animation(.smooth(duration: 0.5, extraBounce: 0.18), value: phase)
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
                artNamespace: artNamespace,
                width: geometry.width,
                height: geometry.height
            )
            .transition(.opacity)
        case .titleBanner:
            TitleBannerView(
                track: nowPlaying.snapshot.track,
                isPlaying: nowPlaying.snapshot.isPlaying,
                artNamespace: artNamespace,
                width: geometry.width,
                height: geometry.height
            )
            .transition(.opacity)
        case .expanded:
            ExpandedPhaseView(
                snapshot: nowPlaying.snapshot,
                transport: transport,
                artNamespace: artNamespace,
                width: geometry.width,
                height: geometry.height
            )
            .transition(.opacity)
        }
    }
}
