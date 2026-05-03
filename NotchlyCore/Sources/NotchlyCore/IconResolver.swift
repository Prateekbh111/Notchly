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

    /// Name-based fallback when vendor/product IDs are unavailable
    /// (`IOBluetoothDevice` doesn't expose them on public API).
    public static func resolveByName(
        _ name: String,
        classOfDevice: UInt32
    ) -> BluetoothIconKind {
        let lower = name.lowercased()

        if lower.contains("airpods pro") { return .airpodsPro }
        if lower.contains("airpods max") { return .airpodsMax }
        if lower.contains("airpods")     { return .airpods }

        if lower.contains("powerbeats pro") || lower.contains("beats fit") || lower.contains("beats studio buds") {
            return .beatsEarbuds
        }
        if lower.contains("beats") {
            return .beatsHeadphones
        }

        return resolve(vendorID: 0, productID: 0, classOfDevice: classOfDevice)
    }
}
