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
    @State private var previousPhaseRank: Int = 0
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private static func rank(_ phase: Phase) -> Int {
        switch phase {
        case .idle:        return 0
        case .compact:     return 1
        case .titleBanner: return 2
        case .expanded:    return 3
        }
    }

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

    // Constant top inverse radius across visible phases — keeps pill body
    // anchor invariant during shape morph, avoids vertical jump.
    private static let topInvR: CGFloat = 6

    private var transitionAnimation: Animation {
        let nextRank = Self.rank(phase)
        let isExpanding = nextRank > previousPhaseRank
        if isExpanding {
            return .spring(response: 0.42, dampingFraction: 0.78)
        } else {
            return .spring(response: 0.38, dampingFraction: 0.86)
        }
    }

    private var geometry: Geometry {
        switch phase {
        case .idle:
            return Geometry(width: notchSize.width, height: notchSize.height, bottomRadius: 12, topInvertedRadius: Self.topInvR)
        case .compact:
            return Geometry(width: 257, height: notchSize.height, bottomRadius: 12, topInvertedRadius: Self.topInvR)
        case .titleBanner:
            return Geometry(width: 257, height: 60, bottomRadius: 20, topInvertedRadius: Self.topInvR)
        case .expanded:
            return Geometry(width: 345, height: 174, bottomRadius: 40, topInvertedRadius: Self.topInvR+4)
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
                    SharedArtwork(
                        snapshot: nowPlaying.snapshot,
                        namespace: artNamespace,
                        cornerRadius: phase == .expanded ? 10 : 6,
                        visible: phase != .idle
                    )
                    .frame(width: g.width, height: g.height, alignment: .top)
                    .clipShape(
                        NotchShape(
                            width: g.width,
                            height: g.height,
                            bottomRadius: g.bottomRadius,
                            topInvertedRadius: 0
                        )
                    )
                    .allowsHitTesting(false)
                    SharedEQ(
                        isPlaying: nowPlaying.snapshot.isPlaying,
                        namespace: artNamespace,
                        visible: phase != .idle
                    )
                    .frame(width: g.width, height: g.height, alignment: .top)
                    .clipShape(
                        NotchShape(
                            width: g.width,
                            height: g.height,
                            bottomRadius: g.bottomRadius,
                            topInvertedRadius: 0
                        )
                    )
                    .allowsHitTesting(false)
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
        .animation(transitionAnimation, value: phase)
        .onReceive(tick) { now in nowTick = now }
        .onChange(of: phase) { _, newPhase in
            previousPhaseRank = Self.rank(newPhase)
        }
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
            .transition(.opacity.animation(.easeOut(duration: 0.25).delay(0.1)))
        case .titleBanner:
            TitleBannerView(
                track: nowPlaying.snapshot.track,
                isPlaying: nowPlaying.snapshot.isPlaying,
                artNamespace: artNamespace,
                width: geometry.width,
                height: geometry.height,
                notchInset: notchSize.height
            )
            .transition(.opacity.animation(.easeOut(duration: 0.25).delay(0.1)))
        case .expanded:
            ExpandedPhaseView(
                snapshot: nowPlaying.snapshot,
                transport: transport,
                artNamespace: artNamespace,
                width: geometry.width,
                height: geometry.height,
                notchInset: notchSize.height
            )
            .transition(.opacity.animation(.easeOut(duration: 0.25).delay(0.1)))
        }
    }
}

private struct SharedArtwork: View {
    let snapshot: NowPlayingSnapshot
    let namespace: Namespace.ID
    let cornerRadius: CGFloat
    let visible: Bool

    var body: some View {
        ArtworkView(data: snapshot.track?.artwork)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black.opacity(snapshot.isPlaying ? 0 : 0.35))
            )
            .opacity(visible ? (snapshot.isPlaying ? 1 : 0.7) : 0)
            .matchedGeometryEffect(id: "artwork", in: namespace, isSource: false)
    }
}

private struct SharedEQ: View {
    let isPlaying: Bool
    let namespace: Namespace.ID
    let visible: Bool

    var body: some View {
        EQGlyphView(isPlaying: isPlaying)
            .opacity(visible ? (isPlaying ? 1 : 0.45) : 0)
            .matchedGeometryEffect(id: "eq", in: namespace, isSource: false)
    }
}
