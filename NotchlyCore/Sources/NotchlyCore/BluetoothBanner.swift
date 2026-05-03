import Foundation

public struct BluetoothBannerPayload: Equatable, Sendable {
    public let deviceID: String
    public let displayName: String
    public let iconKind: BluetoothIconKind
    public let battery: BatteryReading

    public init(
        deviceID: String,
        displayName: String,
        iconKind: BluetoothIconKind,
        battery: BatteryReading
    ) {
        self.deviceID = deviceID
        self.displayName = displayName
        self.iconKind = iconKind
        self.battery = battery
    }
}

public enum BluetoothIconKind: Equatable, Sendable {
    case airpods
    case airpodsPro
    case airpodsMax
    case beatsHeadphones
    case beatsEarbuds
    case genericHeadphones
    case genericSpeaker
}

public enum BatteryReading: Equatable, Sendable {
    case single(Int)
    case airpods(left: Int?, right: Int?, caseLevel: Int?)
    case unknown
}

public extension BatteryReading {
    /// Lowest of left/right buds (in-ear is what user cares about).
    /// Falls back to case only if both buds are nil.
    var displayLevel: Double? {
        switch self {
        case .single(let n):
            return Double(n) / 100.0
        case .airpods(let l, let r, let c):
            let buds = [l, r].compactMap { $0 }
            if let m = buds.min() { return Double(m) / 100.0 }
            if let c { return Double(c) / 100.0 }
            return nil
        case .unknown:
            return nil
        }
    }
}
