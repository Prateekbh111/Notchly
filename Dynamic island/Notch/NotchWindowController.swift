import AppKit
import SwiftUI
import DynamicIslandCore

@MainActor
final class NotchWindowController {
    static let panelWidth: CGFloat = 500
    static let panelHeight: CGFloat = 240

    private var panel: NotchPanel?
    private let nowPlaying: NowPlayingService
    private let transport: TransportController
    private let hover: HoverTracker
    private var screen: NSScreen

    private var notchCenterX: CGFloat = 0
    private var hotspotSize: CGSize = .zero
    private var expandedSize: CGSize = CGSize(width: 360, height: 200)

    private var cursorTimer: DispatchSourceTimer?

    init(
        screen: NSScreen,
        nowPlaying: NowPlayingService,
        transport: TransportController,
        hover: HoverTracker
    ) {
        self.screen = screen
        self.nowPlaying = nowPlaying
        self.transport = transport
        self.hover = hover

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

    func show() {
        let frame = computeFrame(for: screen)
        let panel = NotchPanel(contentRect: frame)
        panel.ignoresMouseEvents = true

        let notchSize: CGSize = {
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
        let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.screens.first(where: { $0.frame.maxY >= mouse.y })
            ?? screen
        let inside = isCursorInHoverRegion(mouse: mouse, on: activeScreen)
        if hover.isHovered != inside {
            hover.setHovered(inside)
        }
        if panel.ignoresMouseEvents != !inside {
            panel.ignoresMouseEvents = !inside
        }
    }

    private func isCursorInHoverRegion(mouse: NSPoint, on screen: NSScreen) -> Bool {
        let topY = screen.frame.maxY
        let centerX: CGFloat
        if let leftMaxX = screen.auxiliaryTopLeftArea?.maxX,
           let rightMinX = screen.auxiliaryTopRightArea?.minX {
            centerX = (leftMaxX + rightMinX) / 2
        } else {
            centerX = screen.frame.midX
        }
        let size = hover.isHovered ? expandedSize : hotspotSize
        let halfW = size.width / 2
        // Open-top check: any cursor above bottomY and within horizontal band
        // counts. Catches cursor pegged at top edge (y == topY) and slight
        // overshoots from fast moves.
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
