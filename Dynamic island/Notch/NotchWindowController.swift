import AppKit
import SwiftUI
import DynamicIslandCore

@MainActor
final class NotchWindowController {
    static let panelWidth: CGFloat = 360
    static let panelHeight: CGFloat = 200

    private var panel: NotchPanel?
    private let nowPlaying: NowPlayingService
    private let transport: TransportController
    private let hover: HoverTracker
    private var screen: NSScreen

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

    func show() {
        let frame = computeFrame(for: screen)
        let panel = NotchPanel(contentRect: frame)

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

        let notchHotspotWidth: CGFloat = notchSize.width + 40

        let root = NotchView(
            nowPlaying: nowPlaying,
            transport: transport,
            hover: hover,
            notchHotspotWidth: notchHotspotWidth,
            notchSize: notchSize
        )

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: frame.size)
        host.safeAreaRegions = []

        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        self.panel = panel
    }

    private func computeFrame(for screen: NSScreen) -> NSRect {
        let width = Self.panelWidth
        let height = Self.panelHeight
        let notchCenterX: CGFloat
        if let leftMaxX = screen.auxiliaryTopLeftArea?.maxX,
           let rightMinX = screen.auxiliaryTopRightArea?.minX {
            notchCenterX = (leftMaxX + rightMinX) / 2
        } else {
            notchCenterX = screen.frame.midX
        }
        let originX = notchCenterX - width / 2
        let originY = screen.frame.maxY - height
        return NSRect(x: originX, y: originY, width: width, height: height)
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
