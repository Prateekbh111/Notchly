import AppKit
import SwiftUI
import NotchlyCore

@MainActor
final class NotchWindowController {
    static let panelWidth: CGFloat = 500
    static let panelHeight: CGFloat = 240

    private var panel: NotchPanel?
    private let nowPlaying: NowPlayingService
    private let transport: TransportController
    private let hover: HoverTracker
    private let hudService: SystemHUDService
    private var screen: NSScreen

    private var notchCenterX: CGFloat = 0
    private var notchSize: CGSize = CGSize(width: 200, height: 32)
    private var hotspotSize: CGSize = .zero

    private var cursorTimer: DispatchSourceTimer?

    init(
        screen: NSScreen,
        nowPlaying: NowPlayingService,
        transport: TransportController,
        hover: HoverTracker,
        hudService: SystemHUDService
    ) {
        self.screen = screen
        self.nowPlaying = nowPlaying
        self.transport = transport
        self.hover = hover
        self.hudService = hudService

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        cursorTimer?.cancel()
    }

    func hide() {
        cursorTimer?.cancel()
        cursorTimer = nil
        panel?.orderOut(nil)
    }

    func show() {
        let frame = computeFrame(for: screen)
        let panel = NotchPanel(contentRect: frame)
        panel.ignoresMouseEvents = true

        notchSize = {
            if let leftMaxX = screen.auxiliaryTopLeftArea?.maxX,
               let rightMinX = screen.auxiliaryTopRightArea?.minX,
               let topInset = screen.safeAreaInsets.top as CGFloat? {
                let width = rightMinX - leftMaxX
                let height = max(topInset, 32)
                return CGSize(width: width, height: height)
            }
            return CGSize(width: 200, height: 32)
        }()

        let notchHotspotWidth: CGFloat = notchSize.width + 60
        let notchHotspotHeight: CGFloat = notchSize.height
        hotspotSize = CGSize(width: notchHotspotWidth, height: notchHotspotHeight)

        let root = NotchView(
            nowPlaying: nowPlaying,
            transport: transport,
            hover: hover,
            hudService: hudService,
            notchHotspotWidth: notchHotspotWidth,
            notchHotspotHeight: notchHotspotHeight,
            notchSize: notchSize
        )

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: frame.size)
        host.safeAreaRegions = []

        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        self.panel = panel

        startCursorPolling()
    }

    private func computeFrame(for screen: NSScreen) -> NSRect {
        if let leftMaxX = screen.auxiliaryTopLeftArea?.maxX,
           let rightMinX = screen.auxiliaryTopRightArea?.minX {
            notchCenterX = (leftMaxX + rightMinX) / 2
        } else {
            notchCenterX = screen.frame.midX
        }
        return screen.frame
    }

    private func startCursorPolling() {
        cursorTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0 / 120.0, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.updateHoverFromCursor() }
        }
        timer.activate()
        cursorTimer = timer
        updateHoverFromCursor()
    }

    private func updateHoverFromCursor() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let sf = screen.frame
        let onNotchScreen = mouse.x >= sf.minX && mouse.x <= sf.maxX
                         && mouse.y >= sf.minY && mouse.y <= sf.maxY
        let inside = onNotchScreen && isCursorInHoverRegion(mouse: mouse)
        if hover.isHovered != inside {
            hover.setHovered(inside)
        }
        if panel.ignoresMouseEvents != !inside {
            panel.ignoresMouseEvents = !inside
        }
    }

    // Trigger region matches current visual phase size — idle uses notch
    // hardware bounds, compact/titleBanner use their pill sizes, expanded
    // uses full expanded pill. Cursor must stay within current state bounds
    // to remain hovered; exit collapses back to previous state.
    private func isCursorInHoverRegion(mouse: NSPoint) -> Bool {
        let topY = screen.frame.maxY
        let centerX = notchCenterX
        let phase = PhaseReducer.reduce(
            hovered: hover.isHovered,
            hasMedia: nowPlaying.hasMedia,
            recentChange: nowPlaying.recentChange(now: Date())
        )
        let size: CGSize
        switch phase {
        case .idle:
            size = CGSize(width: notchSize.width, height: notchSize.height)
        case .compact:
            size = CGSize(width: 257, height: notchSize.height)
        case .titleBanner:
            size = CGSize(width: 257, height: 60)
        case .expanded:
            size = CGSize(width: 345, height: 174)
        }
        let halfW = size.width / 2
        let bottomY = topY - size.height
        return mouse.y >= bottomY && abs(mouse.x - centerX) <= halfW
    }

    @objc private func screensChanged() {
        guard let panel = panel,
              let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else {
            return
        }
        self.screen = screen
        panel.setFrame(computeFrame(for: screen), display: true)
    }
}
