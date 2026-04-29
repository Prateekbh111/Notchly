import XCTest
@testable import DynamicIslandCore

final class PhaseReducerTests: XCTestCase {
    func test_idle_whenNoMediaNoHover() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: false), .idle)
    }

    func test_compact_whenMediaNoHover() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: true), .compact)
    }

    func test_expanded_whenHoverNoMedia() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: false), .expanded)
    }

    func test_expanded_whenHoverAndMedia() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: true), .expanded)
    }
}
