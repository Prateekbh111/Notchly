import XCTest
@testable import DynamicIslandCore

final class BatteryReadingTests: XCTestCase {
    func test_singleReading_displayLevelIsPercentDividedBy100() {
        XCTAssertEqual(BatteryReading.single(0).displayLevel, 0.0)
        XCTAssertEqual(BatteryReading.single(50).displayLevel, 0.5)
        XCTAssertEqual(BatteryReading.single(100).displayLevel, 1.0)
    }

    func test_airpodsReading_displayLevelIsLowestBud_ignoresCase() {
        let r = BatteryReading.airpods(left: 97, right: 90, caseLevel: 30)
        XCTAssertEqual(r.displayLevel, 0.90)
    }

    func test_airpodsReading_skipsNilBud() {
        let r = BatteryReading.airpods(left: nil, right: 60, caseLevel: 90)
        XCTAssertEqual(r.displayLevel, 0.60)
    }

    func test_airpodsReading_fallsBackToCaseWhenBothBudsNil() {
        let r = BatteryReading.airpods(left: nil, right: nil, caseLevel: 75)
        XCTAssertEqual(r.displayLevel, 0.75)
    }

    func test_airpodsReading_allNilReturnsNil() {
        let r = BatteryReading.airpods(left: nil, right: nil, caseLevel: nil)
        XCTAssertNil(r.displayLevel)
    }

    func test_unknownReading_displayLevelIsNil() {
        XCTAssertNil(BatteryReading.unknown.displayLevel)
    }
}
