import XCTest
@testable import NotchlyCore

@MainActor
final class NowPlayingServiceRecentChangeTests: XCTestCase {
    private func track(_ title: String) -> Track {
        Track(title: title, artist: "A", album: nil, artwork: nil, duration: 100)
    }

    func test_recentChangeIsFalseInitially() {
        let bridge = FakeBridge()
        let service = NowPlayingService(bridge: bridge)
        XCTAssertFalse(service.recentChange(now: Date(timeIntervalSince1970: 0)))
    }

    func test_recentChangeFlipsTrueOnTitleChange() async {
        let bridge = FakeBridge()
        let now = Date(timeIntervalSince1970: 100)
        let service = NowPlayingService(bridge: bridge, clock: { now })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()

        XCTAssertTrue(service.recentChange(now: now))
    }

    func test_recentChangeStaysTrueWithin4Seconds() async {
        let bridge = FakeBridge()
        let now = Date(timeIntervalSince1970: 100)
        let service = NowPlayingService(bridge: bridge, clock: { now })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()

        XCTAssertTrue(service.recentChange(now: now.addingTimeInterval(3.99)))
    }

    func test_recentChangeFalseAfter4Seconds() async {
        let bridge = FakeBridge()
        let now = Date(timeIntervalSince1970: 100)
        let service = NowPlayingService(bridge: bridge, clock: { now })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()

        XCTAssertFalse(service.recentChange(now: now.addingTimeInterval(4.01)))
    }

    func test_sameTitleDoesNotBumpChange() async {
        let bridge = FakeBridge()
        let firstNow = Date(timeIntervalSince1970: 100)
        var clockNow = firstNow
        let service = NowPlayingService(bridge: bridge, clock: { clockNow })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()
        clockNow = firstNow.addingTimeInterval(10)
        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 5))
        await Task.yield()

        XCTAssertFalse(service.recentChange(now: clockNow))
    }
}
