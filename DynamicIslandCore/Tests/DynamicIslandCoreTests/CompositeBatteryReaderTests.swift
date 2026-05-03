import XCTest
@testable import DynamicIslandCore

final class CompositeBatteryReaderTests: XCTestCase {
    func test_registryHit_returnsImmediatelyAndDoesNotCallFallback() async {
        let fallbackCalls = LockedCounter()
        let reader = CompositeBatteryReader(
            fastPath: { _, _, _ in .single(82) },
            fallback: { _, _, _ in
                fallbackCalls.increment()
                return .single(33)
            }
        )

        let captured = LockedReadings()
        await reader.read(deviceID: "AA:BB", vendorID: 0, productID: 0) { captured.append($0) }

        XCTAssertEqual(captured.values, [.single(82)])
        XCTAssertEqual(fallbackCalls.value, 0)
    }

    func test_registryMiss_emitsUnknownThenFallbackResult() async {
        let reader = CompositeBatteryReader(
            fastPath: { _, _, _ in .unknown },
            fallback: { _, _, _ in .single(45) }
        )

        let captured = LockedReadings()
        await reader.read(deviceID: "AA:BB", vendorID: 0, productID: 0) { captured.append($0) }

        XCTAssertEqual(captured.values, [.unknown, .single(45)])
    }

    func test_registryAndFallbackBothUnknown_emitsUnknownTwice() async {
        let reader = CompositeBatteryReader(
            fastPath: { _, _, _ in .unknown },
            fallback: { _, _, _ in .unknown }
        )

        let captured = LockedReadings()
        await reader.read(deviceID: "AA:BB", vendorID: 0, productID: 0) { captured.append($0) }

        XCTAssertEqual(captured.values, [.unknown, .unknown])
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int = 0
    var value: Int { lock.withLock { _value } }
    func increment() { lock.withLock { _value += 1 } }
}

private final class LockedReadings: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [BatteryReading] = []
    var values: [BatteryReading] { lock.withLock { _values } }
    func append(_ r: BatteryReading) { lock.withLock { _values.append(r) } }
}
