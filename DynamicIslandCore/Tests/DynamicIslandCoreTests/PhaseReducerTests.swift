import XCTest
@testable import DynamicIslandCore

final class PhaseReducerTests: XCTestCase {
    func test_idle_noMediaNoHoverNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: false, recentChange: false), .idle)
    }

    func test_idle_noMediaNoHoverYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: false, recentChange: true), .idle)
    }

    func test_compact_mediaNoHoverNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: true, recentChange: false), .compact)
    }

    func test_titleBanner_mediaNoHoverYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: true, recentChange: true), .titleBanner)
    }

    func test_expanded_hoverNoMediaNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: false, recentChange: false), .expanded)
    }

    func test_expanded_hoverNoMediaYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: false, recentChange: true), .expanded)
    }

    func test_expanded_hoverMediaNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: true, recentChange: false), .expanded)
    }

    func test_expanded_hoverMediaYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: true, recentChange: true), .expanded)
    }
}
