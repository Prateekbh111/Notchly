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
        NSLog("[MR] bridge starting, dlopen path=%@", path)
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

        NSLog("[MR] dlopen handle=0x%lx, getInfo=%@, sendCommand=%@, register=%@, setCanBe=%@",
              UInt(bitPattern: handle),
              getInfo == nil ? "nil" : "ok",
              sendCommand == nil ? "nil" : "ok",
              registerForNotifications == nil ? "nil" : "ok",
              setCanBeNowPlaying == nil ? "nil" : "ok")

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
        NSLog("[MR] bridge stopping")
        pollTimer?.invalidate()
        pollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let handle = handle { dlclose(handle) }
        handle = nil
    }

    func send(_ command: MediaCommand) -> Bool {
        let result = sendCommand?(command.rawValue, nil) ?? false
        if !result {
            NSLog("[MR] send(%d) returned false (no active client?)", command.rawValue)
        }
        return result
    }

    private func fetchAndPublish() {
        guard let getInfo else {
            NSLog("[MR] getInfo function unavailable, publishing empty")
            onChange?(.empty)
            return
        }
        getInfo(.main) { [weak self] info in
            // Log all keys + scalar values
            NSLog("[MR] callback fired, info keys: %@", info.keys.sorted().joined(separator: ", "))
            for (key, value) in info.sorted(by: { $0.key < $1.key }) {
                if key == "kMRMediaRemoteNowPlayingInfoArtworkData",
                   let data = value as? Data {
                    NSLog("[MR]   %@ = <Data %d bytes>", key, data.count)
                } else {
                    NSLog("[MR]   %@ = %@", key, String(describing: value))
                }
            }

            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let artwork = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data

            // More permissive: accept if any of title / artist / album non-empty
            let displayTitle: String? = {
                if let t = title, !t.isEmpty { return t }
                if let a = artist, !a.isEmpty { return a }
                if let al = album, !al.isEmpty { return al }
                return nil
            }()

            let track: Track? = {
                guard let displayTitle else { return nil }
                return Track(
                    title: displayTitle,
                    artist: artist ?? "",
                    album: album,
                    artwork: artwork,
                    duration: duration
                )
            }()

            let snapshot = NowPlayingSnapshot(track: track, isPlaying: rate > 0, elapsed: elapsed)
            NSLog("[MR] resolved: title=%@ artist=%@ album=%@ duration=%.1f elapsed=%.1f rate=%.2f track=%@",
                  title ?? "nil", artist ?? "nil", album ?? "nil",
                  duration, elapsed, rate,
                  track == nil ? "nil" : "non-nil")
            self?.onChange?(snapshot)
        }
    }
}
