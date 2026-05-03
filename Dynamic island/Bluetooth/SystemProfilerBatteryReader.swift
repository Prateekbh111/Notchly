import Foundation
import DynamicIslandCore

actor SystemProfilerBatteryReader {
    private struct CacheEntry {
        let reading: BatteryReading
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private var inFlight: Task<Void, Never>?
    private let cacheTTL: TimeInterval = 30

    func read(deviceID: String) async -> BatteryReading {
        let key = normalize(deviceID)
        if let entry = cache[key], Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return entry.reading
        }

        if let task = inFlight {
            _ = await task.value
            if let entry = cache[key], Date().timeIntervalSince(entry.timestamp) < cacheTTL {
                return entry.reading
            }
        }

        let task = Task { await refreshCache() }
        inFlight = task
        await task.value
        inFlight = nil

        return cache[key]?.reading ?? .unknown
    }

    private func refreshCache() async {
        let json: Data? = await Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            proc.arguments = ["SPBluetoothDataType", "-json", "-timeout", "2"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            do {
                try proc.run()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return proc.terminationStatus == 0 ? data : nil
        }.value

        guard let data = json,
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bt = parsed["SPBluetoothDataType"] as? [[String: Any]] else {
            return
        }

        let now = Date()
        for section in bt {
            if let connected = section["device_connected"] as? [[String: [String: Any]]] {
                for entry in connected {
                    for (_, info) in entry {
                        ingest(deviceInfo: info, now: now)
                    }
                }
            }
        }
    }

    private func ingest(deviceInfo info: [String: Any], now: Date) {
        guard let address = info["device_addr"] as? String else { return }
        let key = normalize(address)

        let main = batteryInt(info["device_batteryLevelMain"])
        let left = batteryInt(info["device_batteryLevelLeft"])
        let right = batteryInt(info["device_batteryLevelRight"])
        let caseLevel = batteryInt(info["device_batteryLevelCase"])

        let reading: BatteryReading
        if left != nil || right != nil || caseLevel != nil {
            reading = .airpods(left: left, right: right, caseLevel: caseLevel)
        } else if let m = main {
            reading = .single(m)
        } else {
            reading = .unknown
        }

        cache[key] = CacheEntry(reading: reading, timestamp: now)
    }

    private func batteryInt(_ raw: Any?) -> Int? {
        guard let s = raw as? String else { return nil }
        let digits = s.filter { $0.isNumber }
        return Int(digits)
    }

    private func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
