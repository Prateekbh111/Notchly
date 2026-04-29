import XCTest
@testable import DynamicIslandCore

final class TrackTests: XCTestCase {
    func test_trackEqualityIgnoresElapsed() {
        let a = Track(title: "DOUBLE UP", artist: "Sukha", album: "X", artwork: nil, duration: 174)
        let b = Track(title: "DOUBLE UP", artist: "Sukha", album: "X", artwork: nil, duration: 174)
        XCTAssertEqual(a, b)
    }

    func test_trackInequalityWhenTitleDiffers() {
        let a = Track(title: "A", artist: "X", album: nil, artwork: nil, duration: 0)
        let b = Track(title: "B", artist: "X", album: nil, artwork: nil, duration: 0)
        XCTAssertNotEqual(a, b)
    }
}
