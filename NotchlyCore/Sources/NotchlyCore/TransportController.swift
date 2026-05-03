import Foundation

public final class TransportController: Sendable {
    private let bridge: MediaRemoteBridge

    public init(bridge: MediaRemoteBridge) {
        self.bridge = bridge
    }

    @discardableResult public func playPause() -> Bool { bridge.send(.togglePlayPause) }
    @discardableResult public func next() -> Bool { bridge.send(.next) }
    @discardableResult public func previous() -> Bool { bridge.send(.previous) }
    @discardableResult public func toggleShuffle() -> Bool { bridge.send(.toggleShuffle) }
}
