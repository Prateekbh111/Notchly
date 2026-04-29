import Foundation
import AppKit
import DynamicIslandCore

final class RealMediaRemoteBridge: MediaRemoteBridge, @unchecked Sendable {
    var onChange: (@Sendable (NowPlayingSnapshot) -> Void)?

    private typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (Int, [String: Any]?) -> Bool
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias SetCanBeNowPlayingFn = @convention(c) (Bool) -> Void

    private var handle: UnsafeMutableRawPointer?
    private var getInfo: GetNowPlayingInfoFn?
    private var sendCommand: SendCommandFn?
    private var registerForNotifications: RegisterFn?
    private var setCanBeNowPlaying: SetCanBeNowPlayingFn?
    private var pollTimer: Timer?

    private static let infoChangedName = "kMRMediaRemoteNowPlayingInfoDidChangeNotification"
    private static let appChangedName = "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"

    func start() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        self.handle = handle

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(sym, to: GetNowPlayingInfoFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(sym, to: SendCommandFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSetCanBeNowPlayingApplication") {
            setCanBeNowPlaying = unsafeBitCast(sym, to: SetCanBeNowPlayingFn.self)
            setCanBeNowPlaying?(false)
        }

        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerForNotifications = unsafeBitCast(sym, to: RegisterFn.self)
            registerForNotifications?(.main)
        }

        let center = DistributedNotificationCenter.default()
        center.addObserver(
            forName: NSNotification.Name(Self.infoChangedName),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchAndPublish()
        }
        center.addObserver(
            forName: NSNotification.Name(Self.appChangedName),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchAndPublish()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchAndPublish()
        }

        fetchAndPublish()

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchAndPublish()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let handle = handle { dlclose(handle) }
        handle = nil
    }

    func send(_ command: MediaCommand) {
        _ = sendCommand?(command.rawValue, nil)
    }

    private func fetchAndPublish() {
        guard let getInfo else {
            onChange?(.empty)
            return
        }
        getInfo(.main) { [weak self] info in
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let artwork = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data

            let track: Track? = {
                guard let title, !title.isEmpty else { return nil }
                return Track(
                    title: title,
                    artist: artist ?? "",
                    album: album,
                    artwork: artwork,
                    duration: duration
                )
            }()

            let snapshot = NowPlayingSnapshot(track: track, isPlaying: rate > 0, elapsed: elapsed)
            self?.onChange?(snapshot)
        }
    }
}
