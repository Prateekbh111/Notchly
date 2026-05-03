import Foundation
import Combine

@MainActor
public final class NowPlayingService: ObservableObject {
    @Published public private(set) var snapshot: NowPlayingSnapshot = .empty
    @Published public private(set) var lastTrackChangeAt: Date?

    public var hasMedia: Bool { snapshot.track != nil }

    public func recentChange(now: Date, window: TimeInterval = 4.0) -> Bool {
        guard let lastTrackChangeAt else { return false }
        return now.timeIntervalSince(lastTrackChangeAt) < window
    }

    private let bridge: MediaRemoteBridge
    private let clock: @Sendable () -> Date

    public init(
        bridge: MediaRemoteBridge,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.bridge = bridge
        self.clock = clock
        bridge.onChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.ingest(snapshot)
            }
        }
        bridge.start()
    }

    deinit {
        bridge.stop()
    }

    private func ingest(_ next: NowPlayingSnapshot) {
        let prevKey = identityKey(snapshot.track)
        let nextKey = identityKey(next.track)
        if nextKey != nil && nextKey != prevKey {
            lastTrackChangeAt = clock()
        }
        snapshot = next
    }

    private func identityKey(_ track: Track?) -> String? {
        guard let track else { return nil }
        return "\(track.title)\u{1F}\(track.artist)"
    }
}
