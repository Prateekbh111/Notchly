import Foundation
import IOKit
import NotchlyCore

enum IORegistryBatteryReader {
    static func read(deviceID: String) -> BatteryReading {
        let normalizedTarget = normalize(deviceID)

        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return .unknown
        }
        defer { IOObjectRelease(iter) }

        var bestSingle: Int? = nil
        var bestLeft: Int? = nil
        var bestRight: Int? = nil
        var bestCase: Int? = nil
        var matched = false

        while case let entry = IOIteratorNext(iter), entry != 0 {
            defer { IOObjectRelease(entry) }

            guard let address = stringProperty(entry, "DeviceAddress") else { continue }
            guard normalize(address) == normalizedTarget else { continue }

            matched = true
            if let v = intProperty(entry, "BatteryPercentLeft") { bestLeft = v }
            if let v = intProperty(entry, "BatteryPercentRight") { bestRight = v }
            if let v = intProperty(entry, "BatteryPercentCase") { bestCase = v }
            if let v = intProperty(entry, "BatteryPercent") { bestSingle = v }
        }

        guard matched else { return .unknown }

        if bestLeft != nil || bestRight != nil || bestCase != nil {
            return .airpods(left: bestLeft, right: bestRight, caseLevel: bestCase)
        }
        if let single = bestSingle {
            return .single(single)
        }
        return .unknown
    }

    private static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private static func stringProperty(_ entry: io_object_t, _ key: String) -> String? {
        guard let cf = IORegistryEntryCreateCFProperty(
            entry, key as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() else { return nil }
        return cf as? String
    }

    private static func intProperty(_ entry: io_object_t, _ key: String) -> Int? {
        guard let cf = IORegistryEntryCreateCFProperty(
            entry, key as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() else { return nil }
        if let n = cf as? Int { return n }
        if let n = cf as? NSNumber { return n.intValue }
        return nil
    }
}
