import Foundation

public enum IconResolver {
    private static let appleVendorID: UInt16 = 0x004C

    private static let airpodsPIDs: Set<UInt16> = [
        0x200E, 0x200F,
        0x2013, 0x2014,
    ]
    private static let airpodsProPIDs: Set<UInt16> = [
        0x200B, 0x200C,
        0x2024,
    ]
    private static let airpodsMaxPIDs: Set<UInt16> = [
        0x200A,
    ]

    public static func resolve(
        vendorID: UInt16,
        productID: UInt16,
        classOfDevice: UInt32
    ) -> BluetoothIconKind {
        if vendorID == appleVendorID {
            if airpodsProPIDs.contains(productID) { return .airpodsPro }
            if airpodsMaxPIDs.contains(productID) { return .airpodsMax }
            if airpodsPIDs.contains(productID) { return .airpods }
            return .airpods
        }

        let majorClass = (classOfDevice >> 8) & 0x1F
        let minorClass = (classOfDevice >> 2) & 0x3F

        if majorClass == 0x04 {
            switch minorClass {
            case 0x05:
                return .genericSpeaker
            case 0x06, 0x08:
                return .genericHeadphones
            default:
                return .genericHeadphones
            }
        }

        return .genericHeadphones
    }
}
