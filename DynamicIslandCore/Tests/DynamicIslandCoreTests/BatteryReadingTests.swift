import XCTest
@testable import DynamicIslandCore

final class BatteryReadingTests: XCTestCase {
    func test_singleReading_displayLevelIsPercentDividedBy100() {
        XCTAssertEqual(BatteryReading.single(0).displayLevel, 0.0)
        XCTAssertEqual(BatteryReading.single(50).displayLevel, 0.5)
        XCTAssertEqual(BatteryReading.single(100).displayLevel, 1.0)
    }

    func test_airpodsReading_displayLevelIsLowestNonNil() {
        let r = BatteryReading.airpods(left: 80, right: 30, caseLevel: 90)
        XCTAssertEqual(r.displayLevel, 0.30)
    }

    func test_airpodsReading_skipsNilValues() {
        let r = BatteryReading.airpods(left: nil, right: 60, caseLevel: nil)
        XCTAssertEqual(r.displayLevel, 0.60)
    }

    func test_airpodsReading_allNilReturnsNil() {
        let r = BatteryReading.airpods(left: nil, right: nil, caseLevel: nil)
        XCTAssertNil(r.displayLevel)
    }

    func test_unknownReading_displayLevelIsNil() {
        XCTAssertNil(BatteryReading.unknown.displayLevel)
    }
}
