import AppKit
import CoreAudio
import Foundation

@MainActor
final class OutputPickerController {

    struct Device: Identifiable {
        let id: AudioDeviceID
        let name: String
    }

    func presentMenu(at location: NSPoint, in view: NSView) {
        let menu = NSMenu()
        let devices = listOutputDevices()
        if devices.isEmpty {
            let item = NSMenuItem(title: "No outputs available", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let currentID = currentDefaultOutputID()
            for device in devices {
                let item = NSMenuItem(title: device.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.id
                if device.id == currentID {
                    item.state = .on
                }
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: location, in: view)
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? AudioDeviceID else { return }
        setDefaultOutput(deviceID: id)
    }

    private func listOutputDevices() -> [Device] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids.compactMap { id -> Device? in
            guard isOutputDevice(id) else { return nil }
            let name = deviceName(id) ?? "Unknown"
            return Device(id: id, name: name)
        }
    }

    private func isOutputDevice(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, bufferList) == noErr else {
            return false
        }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private func deviceName(_ id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString>.size)
        var name: CFString = "" as CFString
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name) == noErr else {
            return nil
        }
        return name as String
    }

    private func currentDefaultOutputID() -> AudioDeviceID {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr else {
            return 0
        }
        return id
    }

    private func setDefaultOutput(deviceID: AudioDeviceID) {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &id)
        if status != noErr {
            NSLog("[Output] setDefaultOutput failed: %d", status)
        }
    }
}
