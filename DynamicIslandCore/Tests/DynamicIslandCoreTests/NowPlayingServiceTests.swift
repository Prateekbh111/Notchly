import XCTest
import Combine
@testable import DynamicIslandCore

final class FakeBridge: MediaRemoteBridge, @unchecked Sendable {
    var onChange: (@Sendable (NowPlayingSnapshot) -> Void)?
    var started = false
    var stopped = false
    var sentCommands: [MediaCommand] = []

    func start() { started = true }
    func stop() { stopped = true }
    func send(_ command: MediaCommand) { sentCommands.append(command) }

    func emit(_ snapshot: NowPlayingSnapshot) {
        onChange?(snapshot)
    }
}

@MainActor
final class NowPlayingServiceTests: XCTestCase {
    func test_startsBridgeOnInit() {
        let bridge = FakeBridge()
        _ = NowPlayingService(bridge: bridge)
        XCTAssertTrue(bridge.started)
    }

    func test_publishesSnapshotOnBridgeChange() async {
        let bridge = FakeBridge()
        let service = NowPlayingService(bridge: bridge)
        let track = Track(title: "T", artist: "A", album: nil, artwork: nil, duration: 100)
        bridge.emit(NowPlayingSnapshot(track: track, isPlaying: true, elapsed: 12))
        await Task.yield()
        XCTAssertEqual(service.snapshot.track, track)
        XCTAssertTrue(service.snapshot.isPlaying)
    }

    func test_hasMediaIsTrueWhenTrackPresent() async {
        let bridge = FakeBridge()
        let service = NowPlayingService(bridge: bridge)
        XCTAssertFalse(service.hasMedia)
        let track = Track(title: "T", artist: "A", album: nil, artwork: nil, duration: 100)
        bridge.emit(NowPlayingSnapshot(track: track, isPlaying: true, elapsed: 0))
        await Task.yield()
        XCTAssertTrue(service.hasMedia)
    }
}
