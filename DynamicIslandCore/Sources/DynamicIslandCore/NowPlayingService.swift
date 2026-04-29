import Foundation
import Combine

@MainActor
public final class NowPlayingService: ObservableObject {
    @Published public private(set) var snapshot: NowPlayingSnapshot = .empty

    public var hasMedia: Bool { snapshot.track != nil }

    private let bridge: MediaRemoteBridge

    public init(bridge: MediaRemoteBridge) {
        self.bridge = bridge
        bridge.onChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.snapshot = snapshot
            }
        }
        bridge.start()
    }

    deinit {
        bridge.stop()
    }
}
