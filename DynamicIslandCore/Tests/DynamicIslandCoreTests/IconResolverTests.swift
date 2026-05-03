import XCTest
@testable import DynamicIslandCore

final class IconResolverTests: XCTestCase {
    func test_airpodsPro_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x200B, classOfDevice: 0)
        XCTAssertEqual(kind, .airpodsPro)
    }

    func test_airpodsPro2_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x2024, classOfDevice: 0)
        XCTAssertEqual(kind, .airpodsPro)
    }

    func test_airpodsMax_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x200A, classOfDevice: 0)
        XCTAssertEqual(kind, .airpodsMax)
    }

    func test_airpodsGen1_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x200E, classOfDevice: 0)
        XCTAssertEqual(kind, .airpods)
    }

    func test_unknownAppleAudioPID_fallsBackToAirpods() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0xFFFF, classOfDevice: 0)
        XCTAssertEqual(kind, .airpods)
    }

    func test_genericHeadphones_byMinorClassHeadphone() {
        let cod: UInt32 = (0x04 << 8) | (0x06 << 2)
        let kind = IconResolver.resolve(vendorID: 0x1234, productID: 0x5678, classOfDevice: cod)
        XCTAssertEqual(kind, .genericHeadphones)
    }

    func test_genericSpeaker_byMinorClassLoudspeaker() {
        let cod: UInt32 = (0x04 << 8) | (0x05 << 2)
        let kind = IconResolver.resolve(vendorID: 0x1234, productID: 0x5678, classOfDevice: cod)
        XCTAssertEqual(kind, .genericSpeaker)
    }

    func test_genericFallback_whenClassUnrecognized() {
        let kind = IconResolver.resolve(vendorID: 0x1234, productID: 0x5678, classOfDevice: 0)
        XCTAssertEqual(kind, .genericHeadphones)
    }
}
