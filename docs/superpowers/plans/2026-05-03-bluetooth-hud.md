# Bluetooth Connect HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a 3-second HUD banner when a Bluetooth audio device connects to the Mac, displaying a device-aware icon (AirPods/Beats/generic) and the device's battery level when available.

**Architecture:** Pure model and resolver types live in `DynamicIslandCore` (testable, no IOBluetooth). App target adds a `BluetoothMonitorService` that owns IOBluetooth connect notifications, plus battery readers (IORegistry fast path, `system_profiler` fallback). Connect events feed a new method on the existing `SystemHUDService`, which extends its `SystemHUDKind` with a `.bluetooth(payload)` case. `HudPhaseView` switches on the kind to render the new layout.

**Tech Stack:** Swift 5.10, AppKit, SwiftUI, IOBluetooth.framework, IOKit (`IORegistry`), `Foundation.Process` for `system_profiler` fallback. Tests use XCTest in the `DynamicIslandCore` SPM package.

---

## File Structure

**Created (in `DynamicIslandCore/Sources/DynamicIslandCore/`):**
- `BluetoothBanner.swift` — public model types (`BluetoothBannerPayload`, `BluetoothIconKind`, `BatteryReading`).
- `IconResolver.swift` — pure resolver `(vendorID, productID, deviceClass) -> BluetoothIconKind`.
- `BatteryReaderProtocol.swift` — protocol + `CompositeBatteryReader` (composes registry + fallback via injected closures, no IOKit dep so it stays in core).

**Created (in `DynamicIslandCore/Tests/DynamicIslandCoreTests/`):**
- `BatteryReadingTests.swift`
- `IconResolverTests.swift`
- `CompositeBatteryReaderTests.swift`

**Created (in app target `Dynamic island/Bluetooth/`):**
- `IORegistryBatteryReader.swift` — IOKit registry walker.
- `SystemProfilerBatteryReader.swift` — `system_profiler` spawner with cache.
- `BluetoothMonitorService.swift` — owns `IOBluetoothDevice` notifications, orchestrates readers + icon resolver, posts to HUD.

**Modified:**
- `Dynamic island/System/SystemHUDService.swift` — extend `SystemHUDKind` with `.bluetooth`, add `showBluetoothBanner(_:)`, branch dismissal duration.
- `Dynamic island/Phases/HudPhaseView.swift` — render `.bluetooth` case (icon + optional battery ring).
- `Dynamic island/App/AppDelegate.swift` — instantiate `BluetoothMonitorService`, wire it to `hudService`.
- `Dynamic island/Notch/NotchView.swift` — no source change required; existing HUD width path applies.

---

## Task 1: Pure model types in core

**Files:**
- Create: `DynamicIslandCore/Sources/DynamicIslandCore/BluetoothBanner.swift`
- Test: `DynamicIslandCore/Tests/DynamicIslandCoreTests/BatteryReadingTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DynamicIslandCore/Tests/DynamicIslandCoreTests/BatteryReadingTests.swift`:

```swift
import XCTest
@testable import DynamicIslandCore

final class BatteryReadingTests: XCTestCase {
    func test_singleReading_displayLevelIsPercentDividedBy100() {
        XCTAssertEqual(BatteryReading.single(0).displayLevel, 0.0)
        XCTAssertEqual(BatteryReading.single(50).displayLevel, 0.5)
        XCTAssertEqual(BatteryReading.single(100).displayLevel, 1.0)
    }

    func test_airpodsReading_displayLevelIsLowestNonNil() {
        let r = BatteryReading.airpods(left: 80, right: 30, caseLevel: 90)
        XCTAssertEqual(r.displayLevel, 0.30)
    }

    func test_airpodsReading_skipsNilValues() {
        let r = BatteryReading.airpods(left: nil, right: 60, caseLevel: nil)
        XCTAssertEqual(r.displayLevel, 0.60)
    }

    func test_airpodsReading_allNilReturnsNil() {
        let r = BatteryReading.airpods(left: nil, right: nil, caseLevel: nil)
        XCTAssertNil(r.displayLevel)
    }

    func test_unknownReading_displayLevelIsNil() {
        XCTAssertNil(BatteryReading.unknown.displayLevel)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd DynamicIslandCore && swift test --filter BatteryReadingTests`
Expected: build failure — `BatteryReading` not defined.

- [ ] **Step 3: Implement the model**

Create `DynamicIslandCore/Sources/DynamicIslandCore/BluetoothBanner.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd DynamicIslandCore && swift test --filter BatteryReadingTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add DynamicIslandCore/Sources/DynamicIslandCore/BluetoothBanner.swift \
        DynamicIslandCore/Tests/DynamicIslandCoreTests/BatteryReadingTests.swift
git commit -m "feat(core): add Bluetooth banner model + BatteryReading.displayLevel"
```

---

## Task 2: Icon resolver

**Files:**
- Create: `DynamicIslandCore/Sources/DynamicIslandCore/IconResolver.swift`
- Test: `DynamicIslandCore/Tests/DynamicIslandCoreTests/IconResolverTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DynamicIslandCore/Tests/DynamicIslandCoreTests/IconResolverTests.swift`:

```swift
import XCTest
@testable import DynamicIslandCore

final class IconResolverTests: XCTestCase {
    func test_airpodsPro_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x200B, classOfDevice: 0)
        XCTAssertEqual(kind, .airpodsPro)
    }

    func test_airpodsPro2_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x2024, classOfDevice: 0)
        XCTAssertEqual(kind, .airpodsPro)
    }

    func test_airpodsMax_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x200A, classOfDevice: 0)
        XCTAssertEqual(kind, .airpodsMax)
    }

    func test_airpodsGen1_byProductID() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0x200E, classOfDevice: 0)
        XCTAssertEqual(kind, .airpods)
    }

    func test_unknownAppleAudioPID_fallsBackToAirpods() {
        let kind = IconResolver.resolve(vendorID: 0x004C, productID: 0xFFFF, classOfDevice: 0)
        XCTAssertEqual(kind, .airpods)
    }

    func test_genericHeadphones_byMinorClassHeadphone() {
        // Major device class 0x04 (audio/video), minor 0x06 (headphones)
        // CoD bits: minor in [2..7], major in [8..12]
        let cod: UInt32 = (0x04 << 8) | (0x06 << 2)
        let kind = IconResolver.resolve(vendorID: 0x1234, productID: 0x5678, classOfDevice: cod)
        XCTAssertEqual(kind, .genericHeadphones)
    }

    func test_genericSpeaker_byMinorClassLoudspeaker() {
        let cod: UInt32 = (0x04 << 8) | (0x05 << 2)
        let kind = IconResolver.resolve(vendorID: 0x1234, productID: 0x5678, classOfDevice: cod)
        XCTAssertEqual(kind, .genericSpeaker)
    }

    func test_genericFallback_whenClassUnrecognized() {
        let kind = IconResolver.resolve(vendorID: 0x1234, productID: 0x5678, classOfDevice: 0)
        XCTAssertEqual(kind, .genericHeadphones)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd DynamicIslandCore && swift test --filter IconResolverTests`
Expected: build failure — `IconResolver` not defined.

- [ ] **Step 3: Implement the resolver**

Create `DynamicIslandCore/Sources/DynamicIslandCore/IconResolver.swift`:

```swift
import Foundation

public enum IconResolver {
    private static let appleVendorID: UInt16 = 0x004C

    private static let airpodsPIDs: Set<UInt16> = [
        0x200E, 0x200F, // gen 1/2
        0x2013, 0x2014, // gen 3
    ]
    private static let airpodsProPIDs: Set<UInt16> = [
        0x200B, 0x200C, // pro 1
        0x2024,         // pro 2
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
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd DynamicIslandCore && swift test --filter IconResolverTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add DynamicIslandCore/Sources/DynamicIslandCore/IconResolver.swift \
        DynamicIslandCore/Tests/DynamicIslandCoreTests/IconResolverTests.swift
git commit -m "feat(core): add IconResolver for Bluetooth audio devices"
```

---

## Task 3: Battery reader protocol + composite

**Files:**
- Create: `DynamicIslandCore/Sources/DynamicIslandCore/BatteryReaderProtocol.swift`
- Test: `DynamicIslandCore/Tests/DynamicIslandCoreTests/CompositeBatteryReaderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DynamicIslandCore/Tests/DynamicIslandCoreTests/CompositeBatteryReaderTests.swift`:

```swift
import XCTest
@testable import DynamicIslandCore

final class CompositeBatteryReaderTests: XCTestCase {
    func test_registryHit_returnsImmediatelyAndDoesNotCallFallback() async {
        var fallbackCalls = 0
        let reader = CompositeBatteryReader(
            fastPath: { _, _, _ in .single(82) },
            fallback: { _, _, _ in
                fallbackCalls += 1
                return .single(33)
            }
        )

        var captured: [BatteryReading] = []
        await reader.read(deviceID: "AA:BB", vendorID: 0, productID: 0) { captured.append($0) }

        XCTAssertEqual(captured, [.single(82)])
        XCTAssertEqual(fallbackCalls, 0)
    }

    func test_registryMiss_emitsUnknownThenFallbackResult() async {
        let reader = CompositeBatteryReader(
            fastPath: { _, _, _ in .unknown },
            fallback: { _, _, _ in .single(45) }
        )

        var captured: [BatteryReading] = []
        await reader.read(deviceID: "AA:BB", vendorID: 0, productID: 0) { captured.append($0) }

        XCTAssertEqual(captured, [.unknown, .single(45)])
    }

    func test_registryAndFallbackBothUnknown_emitsUnknownOnce() async {
        let reader = CompositeBatteryReader(
            fastPath: { _, _, _ in .unknown },
            fallback: { _, _, _ in .unknown }
        )

        var captured: [BatteryReading] = []
        await reader.read(deviceID: "AA:BB", vendorID: 0, productID: 0) { captured.append($0) }

        XCTAssertEqual(captured, [.unknown, .unknown])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd DynamicIslandCore && swift test --filter CompositeBatteryReaderTests`
Expected: build failure — `CompositeBatteryReader` not defined.

- [ ] **Step 3: Implement protocol and composite**

Create `DynamicIslandCore/Sources/DynamicIslandCore/BatteryReaderProtocol.swift`:

```swift
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

    /// Emits the registry result (or .unknown if missing). If unknown, kicks off
    /// the fallback and emits that result when it resolves.
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd DynamicIslandCore && swift test --filter CompositeBatteryReaderTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add DynamicIslandCore/Sources/DynamicIslandCore/BatteryReaderProtocol.swift \
        DynamicIslandCore/Tests/DynamicIslandCoreTests/CompositeBatteryReaderTests.swift
git commit -m "feat(core): add CompositeBatteryReader (fast path + fallback)"
```

---

## Task 4: Extend SystemHUDState with .bluetooth case

**Files:**
- Modify: `Dynamic island/System/SystemHUDService.swift`

This task is a non-functional model extension. We do not have an XCTest target for the app, so the validation here is "the project still compiles." Behavior is exercised in Task 8 (HudPhaseView rendering).

- [ ] **Step 1: Modify the SystemHUDKind enum and SystemHUDState**

Edit `Dynamic island/System/SystemHUDService.swift`. Replace lines 7–16 (the existing `SystemHUDKind` enum and `SystemHUDState` struct) with:

```swift
import DynamicIslandCore
// ... keep existing AppKit / Combine / CoreAudio / Darwin imports above this

enum SystemHUDKind: Equatable {
    case volume
    case brightness
    case bluetooth(BluetoothBannerPayload)
}

struct SystemHUDState: Equatable {
    let kind: SystemHUDKind
    let level: Double
    let muted: Bool
}
```

Note: `import DynamicIslandCore` should already be present in this file's import block (the file imports it indirectly via the app — check; if missing, add it at top). The associated value makes `SystemHUDKind` `Equatable` only if `BluetoothBannerPayload` is `Equatable`, which it is from Task 1.

- [ ] **Step 2: Add showBluetoothBanner method**

In the same file, locate the `private func show(_ state: SystemHUDState)` (around line 361). Add this new method right above it:

```swift
func showBluetoothBanner(_ payload: BluetoothBannerPayload) {
    let state = SystemHUDState(
        kind: .bluetooth(payload),
        level: 0,
        muted: false
    )
    show(state)
}
```

Then modify `show(_:)` to use a kind-dependent dismissal:

```swift
private func show(_ state: SystemHUDState) {
    hud = state
    hideWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        self?.hud = nil
        self?.hideWorkItem = nil
    }
    hideWorkItem = work
    let delay: TimeInterval
    switch state.kind {
    case .bluetooth: delay = 3.0
    case .volume, .brightness: delay = 1.5
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
}
```

- [ ] **Step 3: Build to verify the project still compiles**

Run from the project root:
```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug build 2>&1 | tail -40
```
Expected: `** BUILD SUCCEEDED **` with no errors. (Warnings about `level`/`muted` being unused for `.bluetooth` are acceptable; the fields stay in the struct because `.volume`/`.brightness` still need them.)

- [ ] **Step 4: Commit**

```bash
git add "Dynamic island/System/SystemHUDService.swift"
git commit -m "feat(hud): extend SystemHUDKind with .bluetooth case + 3s dismiss"
```

---

## Task 5: HudPhaseView — render the .bluetooth case

**Files:**
- Modify: `Dynamic island/Phases/HudPhaseView.swift`

- [ ] **Step 1: Replace the iconName computed property and the body**

Open `Dynamic island/Phases/HudPhaseView.swift` and replace its full contents with:

```swift
import SwiftUI
import DynamicIslandCore

struct HudPhaseView: View {
    let state: SystemHUDState
    let height: CGFloat
    let notchWidth: CGFloat
    let leftWidth: CGFloat
    let rightWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: leftWidth, height: height, alignment: .center)
                .contentTransition(.symbolEffect(.replace))

            Color.clear.frame(width: notchWidth)

            rightSlot
                .frame(width: rightWidth - 20, height: height)
                .padding(.horizontal, 5)
        }
        .frame(width: leftWidth + notchWidth + rightWidth, height: height)
    }

    @ViewBuilder
    private var rightSlot: some View {
        switch state.kind {
        case .volume, .brightness:
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35))
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: (rightWidth - 20) * CGFloat(max(0, min(1, state.level))))
            }
            .frame(height: 6)
            .frame(maxHeight: .infinity)

        case .bluetooth(let payload):
            if let level = payload.battery.displayLevel {
                BatteryRing(level: level)
                    .frame(width: 20, height: 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear
            }
        }
    }

    private var iconName: String {
        switch state.kind {
        case .volume:
            if state.muted || state.level <= 0.001 { return "speaker.slash.fill" }
            if state.level < 0.34 { return "speaker.wave.1.fill" }
            if state.level < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return "sun.max.fill"
        case .bluetooth(let payload):
            return symbolName(for: payload.iconKind)
        }
    }

    private func symbolName(for kind: BluetoothIconKind) -> String {
        switch kind {
        case .airpods:            return "airpods"
        case .airpodsPro:         return "airpods.pro"
        case .airpodsMax:         return "airpods.max"
        case .beatsHeadphones:    return "beats.headphones"
        case .beatsEarbuds:       return "beats.earbuds"
        case .genericHeadphones:  return "headphones"
        case .genericSpeaker:     return "hifispeaker.fill"
        }
    }
}

private struct BatteryRing: View {
    let level: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, level))))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(round(level * 100)))")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    private var ringColor: Color {
        if level <= 0.20 { return .red.opacity(0.95) }
        if level <= 0.40 { return .yellow.opacity(0.95) }
        return .white.opacity(0.95)
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug build 2>&1 | tail -40
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Phases/HudPhaseView.swift"
git commit -m "feat(hud): render .bluetooth case with icon + battery ring"
```

---

## Task 6: IORegistryBatteryReader (fast path)

**Files:**
- Create: `Dynamic island/Bluetooth/IORegistryBatteryReader.swift`

- [ ] **Step 1: Create the reader**

Create directory and file:

```bash
mkdir -p "Dynamic island/Bluetooth"
```

Create `Dynamic island/Bluetooth/IORegistryBatteryReader.swift`:

```swift
import Foundation
import IOKit
import DynamicIslandCore

enum IORegistryBatteryReader {
    /// Synchronous IOKit walk. Returns .unknown if no entry has battery keys
    /// for this device. Callable from a background queue.
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
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug build 2>&1 | tail -40
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Bluetooth/IORegistryBatteryReader.swift"
git commit -m "feat(bluetooth): IORegistry battery reader (fast path)"
```

---

## Task 7: SystemProfilerBatteryReader (fallback)

**Files:**
- Create: `Dynamic island/Bluetooth/SystemProfilerBatteryReader.swift`

- [ ] **Step 1: Create the reader**

Create `Dynamic island/Bluetooth/SystemProfilerBatteryReader.swift`:

```swift
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

        // Serialize spawns: wait for any in-flight invocation to finish.
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
        // Values look like "82%" or "82"; strip non-digits.
        let digits = s.filter { $0.isNumber }
        return Int(digits)
    }

    private func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug build 2>&1 | tail -40
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Bluetooth/SystemProfilerBatteryReader.swift"
git commit -m "feat(bluetooth): system_profiler battery reader (fallback, cached)"
```

---

## Task 8: BluetoothMonitorService

**Files:**
- Create: `Dynamic island/Bluetooth/BluetoothMonitorService.swift`

- [ ] **Step 1: Create the service**

Create `Dynamic island/Bluetooth/BluetoothMonitorService.swift`:

```swift
import AppKit
import IOBluetooth
import DynamicIslandCore

@MainActor
final class BluetoothMonitorService {
    private weak var hudService: SystemHUDService?
    private var notificationToken: IOBluetoothUserNotification?
    private var lastEmitTimes: [String: Date] = [:]
    private let dedupeWindow: TimeInterval = 5.0
    private let profilerReader = SystemProfilerBatteryReader()

    init(hudService: SystemHUDService) {
        self.hudService = hudService
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

    @objc private func handleConnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard isAudioDevice(device) else { return }

        let mac = device.addressString ?? ""
        guard !mac.isEmpty else { return }
        if let last = lastEmitTimes[mac], Date().timeIntervalSince(last) < dedupeWindow { return }
        lastEmitTimes[mac] = Date()

        let name = device.name ?? "Bluetooth Device"
        let vendorID = UInt16(truncatingIfNeeded: device.vendorID())
        let productID = UInt16(truncatingIfNeeded: device.productID())
        let cod = device.classOfDevice
        let icon = IconResolver.resolve(
            vendorID: vendorID,
            productID: productID,
            classOfDevice: UInt32(cod)
        )

        Task { [weak self] in
            await self?.resolveBatteryAndEmit(
                mac: mac,
                name: name,
                vendorID: vendorID,
                productID: productID,
                icon: icon
            )
        }
    }

    private func resolveBatteryAndEmit(
        mac: String,
        name: String,
        vendorID: UInt16,
        productID: UInt16,
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
            vendorID: vendorID,
            productID: productID
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
        if majorClass == 0x04 { return true }   // audio/video
        let serviceClasses = (cod >> 13) & 0x7FF
        if serviceClasses & 0x100 != 0 { return true } // audio service bit
        return false
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug build 2>&1 | tail -60
```
Expected: `** BUILD SUCCEEDED **`. If `IOBluetooth` is not linked, Xcode auto-links system frameworks for Swift `import` lines under Dynamic SDK; if a linker error appears about IOBluetooth, add it to "Frameworks, Libraries, and Embedded Content" in the Xcode target settings (do this manually in Xcode UI; pbxproj is auto-managed).

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Bluetooth/BluetoothMonitorService.swift"
git commit -m "feat(bluetooth): BluetoothMonitorService (connect detection + battery)"
```

---

## Task 9: Wire BluetoothMonitorService into AppDelegate

**Files:**
- Modify: `Dynamic island/App/AppDelegate.swift`

- [ ] **Step 1: Add the property and instantiate**

Open `Dynamic island/App/AppDelegate.swift`. Replace the entire file body with:

```swift
import AppKit
import DynamicIslandCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private var nowPlaying: NowPlayingService?
    private var transport: TransportController?
    private var hover: HoverTracker?
    private var hudService: SystemHUDService?
    private var bluetoothMonitor: BluetoothMonitorService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else {
            presentNoNotchAlert()
            NSApp.terminate(nil)
            return
        }

        let bridge = MediaRemoteAdapterBridge()
        let nowPlaying = NowPlayingService(bridge: bridge)
        let transport = TransportController(bridge: bridge)
        let hover = HoverTracker()
        let hudService = SystemHUDService()
        let bluetoothMonitor = BluetoothMonitorService(hudService: hudService)
        bluetoothMonitor.start()

        let controller = NotchWindowController(
            screen: screen,
            nowPlaying: nowPlaying,
            transport: transport,
            hover: hover,
            hudService: hudService
        )
        controller.show()

        self.nowPlaying = nowPlaying
        self.transport = transport
        self.hover = hover
        self.hudService = hudService
        self.bluetoothMonitor = bluetoothMonitor
        self.windowController = controller
    }

    private func presentNoNotchAlert() {
        let alert = NSAlert()
        alert.messageText = "Notch required"
        alert.informativeText = "Dynamic Island requires a MacBook with a notch."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug build 2>&1 | tail -40
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/App/AppDelegate.swift"
git commit -m "feat(app): wire BluetoothMonitorService into AppDelegate"
```

---

## Task 10: Manual smoke verification

This task is human-only — run the app and verify the banner shows on real Bluetooth connects.

- [ ] **Step 1: Run the app**

```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug build
open "$(xcodebuild -project 'Dynamic island.xcodeproj' -scheme 'Dynamic island' -showBuildSettings 2>/dev/null | awk -F' = ' '/CONFIGURATION_BUILD_DIR/ {print $2; exit}')/Dynamic island.app"
```

- [ ] **Step 2: Disconnect and reconnect AirPods (or any audio BT device)**

Open the menu bar Bluetooth menu, click the device to disconnect, then click again to reconnect. Within ~1s of the connect, the notch should expand into the HUD slot showing the device icon and a battery ring (if available).

- [ ] **Step 3: Verify behavior**

Check:
- Banner appears for ~3 seconds, then dismisses.
- AirPods show the AirPods/AirPods Pro/Max SF Symbol per model.
- Generic headphones show the `headphones` symbol.
- Reconnecting within 5s does *not* trigger a second banner (debounce).
- Volume key tap during banner replaces it with the volume HUD (latest-wins).
- App still functions: media titleBanner / compact / expanded all still render correctly.

If any item fails, capture symptoms and revisit the corresponding task.

- [ ] **Step 4: Final commit (only if any inline fixes were needed)**

If smoke testing surfaced issues that needed fixes, commit them with a descriptive message. Otherwise no commit needed.

---

## Self-Review Notes

- **Spec coverage:** Sections 1–7 of the spec map to tasks: model (1), icon (2), composite reader (3), HUD slot (4), view (5), readers (6, 7), monitor + wiring (8, 9), tests (1–3), smoke (10). Edge cases — debounce, audio filter, app-not-running-at-connect, system_profiler timeout/cache — are implemented in the relevant tasks.
- **Type consistency:** `BluetoothBannerPayload`, `BluetoothIconKind`, `BatteryReading`, `BatteryReadFn`, `CompositeBatteryReader`, `IconResolver` are introduced in tasks 1–3 and used identically in tasks 4–9.
- **Out-of-scope items** (per-pod display, disconnects, low-battery alerts, on-demand reveal, non-audio devices) are explicitly absent from tasks.
