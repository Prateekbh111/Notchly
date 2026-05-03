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
    var displayLevel: Double? {
        switch self {
        case .single(let n):
            return Double(n) / 100.0
        case .airpods(let l, let r, let c):
            let vals = [l, r, c].compactMap { $0 }
            guard let m = vals.min() else { return nil }
            return Double(m) / 100.0
        case .unknown:
            return nil
        }
    }
}
