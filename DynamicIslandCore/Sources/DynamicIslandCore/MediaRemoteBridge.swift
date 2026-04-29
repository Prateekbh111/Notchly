import Foundation

public enum MediaCommand: Int, Sendable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case next = 4
    case previous = 5
    case toggleShuffle = 26
}

public struct NowPlayingSnapshot: Equatable, Sendable {
    public let track: Track?
    public let isPlaying: Bool
    public let elapsed: TimeInterval

    public init(track: Track?, isPlaying: Bool, elapsed: TimeInterval) {
        self.track = track
        self.isPlaying = isPlaying
        self.elapsed = elapsed
    }

    public static let empty = NowPlayingSnapshot(track: nil, isPlaying: false, elapsed: 0)
}

public protocol MediaRemoteBridge: AnyObject, Sendable {
    var onChange: (@Sendable (NowPlayingSnapshot) -> Void)? { get set }
    func start()
    func stop()
    @discardableResult
    func send(_ command: MediaCommand) -> Bool
}
