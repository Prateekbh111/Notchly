import XCTest
@testable import NotchlyCore

final class TransportControllerTests: XCTestCase {
    func test_playPauseSendsToggleCommand() {
        let bridge = FakeBridge()
        let controller = TransportController(bridge: bridge)
        controller.playPause()
        XCTAssertEqual(bridge.sentCommands, [.togglePlayPause])
    }

    func test_nextAndPreviousAndShuffle() {
        let bridge = FakeBridge()
        let controller = TransportController(bridge: bridge)
        controller.next()
        controller.previous()
        controller.toggleShuffle()
        XCTAssertEqual(bridge.sentCommands, [.next, .previous, .toggleShuffle])
    }

    func test_playPauseReturnsBridgeBool() {
        let bridge = FakeBridge()
        let controller = TransportController(bridge: bridge)
        let result = controller.playPause()
        XCTAssertTrue(result)
    }
}
