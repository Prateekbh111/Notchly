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

    /// Force a refresh ignoring the cache (used for retry after pairing/connect race).
    func forceRefresh(deviceID: String) async -> BatteryReading {
        let key = normalize(deviceID)
        cache[key] = nil
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
            proc.arguments = ["SPBluetoothDataType", "-json"]
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
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let dict = parsed as? [String: Any],
              let sections = dict["SPBluetoothDataType"] as? [Any] else {
            NSLog("[BT] system_profiler parse failed (top-level)")
            return
        }

        let now = Date()
        var ingested = 0

        for section in sections {
            guard let sec = section as? [String: Any] else { continue }
            for key in ["device_connected", "device_not_connected"] {
                guard let listAny = sec[key] as? [Any] else { continue }
                for entryAny in listAny {
                    guard let entry = entryAny as? [String: Any] else { continue }
                    for (_, infoAny) in entry {
                        guard let info = infoAny as? [String: Any] else { continue }
                        if ingest(deviceInfo: info, now: now) { ingested += 1 }
                    }
                }
            }
        }

        NSLog("[BT] system_profiler ingested \(ingested) device(s); cache size=\(cache.count)")
    }

    @discardableResult
    private func ingest(deviceInfo info: [String: Any], now: Date) -> Bool {
        guard let address = info["device_address"] as? String else { return false }
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
        return true
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
