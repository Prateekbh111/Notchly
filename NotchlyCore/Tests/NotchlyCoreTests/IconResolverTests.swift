import XCTest
@testable import NotchlyCore

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

    func test_resolveByName_airpodsPro() {
        XCTAssertEqual(IconResolver.resolveByName("Prateek's AirPods Pro", classOfDevice: 0), .airpodsPro)
    }

    func test_resolveByName_airpodsMax() {
        XCTAssertEqual(IconResolver.resolveByName("AirPods Max", classOfDevice: 0), .airpodsMax)
    }

    func test_resolveByName_airpodsBase() {
        XCTAssertEqual(IconResolver.resolveByName("Prateek's AirPods", classOfDevice: 0), .airpods)
    }

    func test_resolveByName_powerbeatsPro_isEarbuds() {
        XCTAssertEqual(IconResolver.resolveByName("Powerbeats Pro", classOfDevice: 0), .beatsEarbuds)
    }

    func test_resolveByName_beatsStudio_isHeadphones() {
        XCTAssertEqual(IconResolver.resolveByName("Beats Studio3", classOfDevice: 0), .beatsHeadphones)
    }

    func test_resolveByName_genericFallsBackToCoD() {
        let cod: UInt32 = (0x04 << 8) | (0x05 << 2)
        XCTAssertEqual(IconResolver.resolveByName("UE Boom", classOfDevice: cod), .genericSpeaker)
    }
}
