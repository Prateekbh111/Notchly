import AppKit
import Combine

@MainActor
final class HoverTracker: ObservableObject {
    @Published private(set) var isHovered: Bool = false

    func setHovered(_ hovered: Bool) {
        isHovered = hovered
    }
}
