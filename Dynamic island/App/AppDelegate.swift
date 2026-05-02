import AppKit
import DynamicIslandCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private var nowPlaying: NowPlayingService?
    private var transport: TransportController?
    private var hover: HoverTracker?
    private var hudService: SystemHUDService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else {
            presentNoNotchAlert()
            NSApp.terminate(nil)
            return
        }

        let bridge = MediaRemoteAdapterBridge()
        let nowPlaying = NowPlayingService(bridge: bridge)
        let transport = TransportController(bridge: bridge)
        let hover = HoverTracker()
        let hudService = SystemHUDService()

        let controller = NotchWindowController(
            screen: screen,
            nowPlaying: nowPlaying,
            transport: transport,
            hover: hover,
            hudService: hudService
        )
        controller.show()

        self.nowPlaying = nowPlaying
        self.transport = transport
        self.hover = hover
        self.hudService = hudService
        self.windowController = controller
    }

    private func presentNoNotchAlert() {
        let alert = NSAlert()
        alert.messageText = "Notch required"
        alert.informativeText = "Dynamic Island requires a MacBook with a notch."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }
}
