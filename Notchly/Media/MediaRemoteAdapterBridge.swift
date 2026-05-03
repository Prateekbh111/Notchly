import Foundation
import NotchlyCore
import MediaRemoteAdapter

final class MediaRemoteAdapterBridge: MediaRemoteBridge, @unchecked Sendable {
    var onChange: (@Sendable (NowPlayingSnapshot) -> Void)?

    private let controller = MediaController()

    func start() {
        controller.onTrackInfoReceived = { [weak self] info in
            self?.handle(info)
        }
        controller.startListening()
    }

    func stop() {
        controller.stopListening()
    }

    @discardableResult
    func send(_ command: MediaCommand) -> Bool {
        switch command {
        case .play:            controller.play()
        case .pause:           controller.pause()
        case .togglePlayPause: controller.togglePlayPause()
        case .next:            controller.nextTrack()
        case .previous:        controller.previousTrack()
        case .toggleShuffle:   controller.toggleShuffle()
        }
        return true
    }

    private func handle(_ info: TrackInfo?) {
        guard let info, let title = info.payload.title, !title.isEmpty else {
            onChange?(.empty)
            return
        }
        let payload = info.payload
        let artwork: Data? = payload.artworkDataBase64.flatMap { Data(base64Encoded: $0) }
        let track = Track(
            title: title,
            artist: payload.artist ?? "",
            album: payload.album,
            artwork: artwork,
            duration: (payload.durationMicros ?? 0) / 1_000_000
        )
        let snapshot = NowPlayingSnapshot(
            track: track,
            isPlaying: payload.isPlaying ?? false,
            elapsed: (payload.elapsedTimeMicros ?? 0) / 1_000_000
        )
        onChange?(snapshot)
    }
}
