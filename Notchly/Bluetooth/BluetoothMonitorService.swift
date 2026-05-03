import AppKit
import IOBluetooth
import NotchlyCore

@MainActor
final class BluetoothMonitorService: NSObject {
    private weak var hudService: SystemHUDService?
    private var notificationToken: IOBluetoothUserNotification?
    private var lastEmitTimes: [String: Date] = [:]
    private let dedupeWindow: TimeInterval = 5.0
    private let profilerReader = SystemProfilerBatteryReader()

    init(hudService: SystemHUDService) {
        self.hudService = hudService
        super.init()
    }

    func start() {
        notificationToken = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleConnect(_:device:))
        )
    }

    deinit {
        notificationToken?.unregister()
    }

    @objc nonisolated private func handleConnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // IOBluetooth invokes this on an arbitrary thread; hop to main for state.
        Task { @MainActor [weak self] in
            self?.processConnect(device: device)
        }
    }

    private func processConnect(device: IOBluetoothDevice) {
        guard isAudioDevice(device) else { return }

        let mac = device.addressString ?? ""
        guard !mac.isEmpty else { return }
        if let last = lastEmitTimes[mac], Date().timeIntervalSince(last) < dedupeWindow { return }
        lastEmitTimes[mac] = Date()

        let name = device.name ?? "Bluetooth Device"
        let cod = UInt32(device.classOfDevice)
        let icon = IconResolver.resolveByName(name, classOfDevice: cod)

        Task { [weak self] in
            await self?.resolveBatteryAndEmit(
                mac: mac,
                name: name,
                icon: icon
            )
        }
    }

    private func resolveBatteryAndEmit(
        mac: String,
        name: String,
        icon: BluetoothIconKind
    ) async {
        let battery = await resolveBattery(mac: mac)
        await MainActor.run {
            let payload = BluetoothBannerPayload(
                deviceID: mac,
                displayName: name,
                iconKind: icon,
                battery: battery
            )
            self.hudService?.showBluetoothBanner(payload)
        }
    }

    /// Resolve battery in a single shot — tries IORegistry, then system_profiler,
    /// then retries system_profiler once after a short delay (bluetoothd race).
    /// Returns whatever reading is available; falls back to .unknown.
    private func resolveBattery(mac: String) async -> BatteryReading {
        let fast = await Task.detached(priority: .userInitiated) {
            IORegistryBatteryReader.read(deviceID: mac)
        }.value
        if fast != .unknown { return fast }

        let firstProfile = await profilerReader.read(deviceID: mac)
        if firstProfile != .unknown { return firstProfile }

        try? await Task.sleep(nanoseconds: 1_200_000_000)
        return await profilerReader.forceRefresh(deviceID: mac)
    }

    private func isAudioDevice(_ device: IOBluetoothDevice) -> Bool {
        let cod = UInt32(device.classOfDevice)
        let majorClass = (cod >> 8) & 0x1F
        if majorClass == 0x04 { return true }
        let serviceClasses = (cod >> 13) & 0x7FF
        if serviceClasses & 0x100 != 0 { return true }
        return false
    }
}
