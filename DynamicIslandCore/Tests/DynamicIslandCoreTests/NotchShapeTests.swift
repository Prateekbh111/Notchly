import XCTest
import SwiftUI
@testable import DynamicIslandCore

final class NotchShapeTests: XCTestCase {
    func test_pathBoundsFitInsideRect() {
        let shape = NotchShape(cornerRadius: 16)
        let rect = CGRect(x: 0, y: 0, width: 360, height: 180)
        let path = shape.path(in: rect)
        XCTAssertTrue(rect.insetBy(dx: -1, dy: -1).contains(path.boundingRect))
    }

    func test_pathIsNonEmpty() {
        let shape = NotchShape(cornerRadius: 16)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 200, height: 30))
        XCTAssertFalse(path.isEmpty)
    }
}
