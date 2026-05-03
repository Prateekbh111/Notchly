import Foundation

public typealias BatteryReadFn = @Sendable (
    _ deviceID: String,
    _ vendorID: UInt16,
    _ productID: UInt16
) async -> BatteryReading

public struct CompositeBatteryReader: Sendable {
    private let fastPath: BatteryReadFn
    private let fallback: BatteryReadFn

    public init(fastPath: @escaping BatteryReadFn, fallback: @escaping BatteryReadFn) {
        self.fastPath = fastPath
        self.fallback = fallback
    }

    public func read(
        deviceID: String,
        vendorID: UInt16,
        productID: UInt16,
        emit: @escaping @Sendable (BatteryReading) -> Void
    ) async {
        let primary = await fastPath(deviceID, vendorID, productID)
        emit(primary)
        guard primary == .unknown else { return }
        let secondary = await fallback(deviceID, vendorID, productID)
        emit(secondary)
    }
}
