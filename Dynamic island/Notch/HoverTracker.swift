import AppKit
import Combine

@MainActor
final class HoverTracker: ObservableObject {
    @Published private(set) var isHovered: Bool = false

    func setHovered(_ hovered: Bool) {
        isHovered = hovered
    }
}

final class HoverTrackingView: NSView {
    private let tracker: HoverTracker

    init(tracker: HoverTracker, frame: NSRect) {
        self.tracker = tracker
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        Task { @MainActor in tracker.setHovered(true) }
    }

    // Exit is handled by HoverExitTrackingView (full-panel); suppress here
    // so the small entry hotspot doesn't collapse the expanded card immediately.
    override func mouseExited(with event: NSEvent) {}

    // Return nil so this view never claims mouse clicks; the NSTrackingArea
    // still fires mouseEntered/mouseExited independently of hit-testing.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// Large tracking view that covers the full panel and triggers isHovered = false
// only when the cursor leaves the entire panel area.
final class HoverExitTrackingView: NSView {
    private let tracker: HoverTracker

    init(tracker: HoverTracker, frame: NSRect) {
        self.tracker = tracker
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseExited(with event: NSEvent) {
        Task { @MainActor in tracker.setHovered(false) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
