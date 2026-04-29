import Foundation

public final class TransportController: Sendable {
    private let bridge: MediaRemoteBridge

    public init(bridge: MediaRemoteBridge) {
        self.bridge = bridge
    }

    public func playPause() { bridge.send(.togglePlayPause) }
    public func next() { bridge.send(.next) }
    public func previous() { bridge.send(.previous) }
    public func toggleShuffle() { bridge.send(.toggleShuffle) }
}
