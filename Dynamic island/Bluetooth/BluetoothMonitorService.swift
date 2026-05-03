import AppKit
import IOBluetooth
import DynamicIslandCore

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
        let fastPath: BatteryReadFn = { id, _, _ in
            await Task.detached(priority: .userInitiated) {
                IORegistryBatteryReader.read(deviceID: id)
            }.value
        }
        let profilerReader = self.profilerReader
        let fallback: BatteryReadFn = { id, _, _ in
            await profilerReader.read(deviceID: id)
        }

        let composite = CompositeBatteryReader(fastPath: fastPath, fallback: fallback)

        await composite.read(
            deviceID: mac,
            vendorID: 0,
            productID: 0
        ) { [weak self] reading in
            Task { @MainActor [weak self] in
                let payload = BluetoothBannerPayload(
                    deviceID: mac,
                    displayName: name,
                    iconKind: icon,
                    battery: reading
                )
                self?.hudService?.showBluetoothBanner(payload)
            }
        }
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
