import AppKit
import Combine

@MainActor
final class HoverTracker: ObservableObject {
    @Published private(set) var isHovered: Bool = false
    private var pendingFalse: DispatchWorkItem?

    func setHovered(_ hovered: Bool) {
        if hovered {
            pendingFalse?.cancel()
            pendingFalse = nil
            if !isHovered {
                isHovered = true
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        } else {
            guard pendingFalse == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                self?.isHovered = false
                self?.pendingFalse = nil
            }
            pendingFalse = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50), execute: work)
        }
    }
}
