# Bluetooth Connect HUD — Design

**Date:** 2026-05-03
**Topic:** Extend Dynamic Island to detect Bluetooth audio device connects and surface battery + device-aware icon in the HUD slot.

## Goal

When a Bluetooth audio device (AirPods/Beats/headphones/speaker) connects to the Mac, the notch shows a transient banner with:

- Device icon (AirPods/Beats art when identifiable, generic headphones/speaker otherwise).
- Battery indicator (ring/bar) when available.
- 3-second auto-dismiss.

Disconnect events are intentionally not shown (per brainstorm Q2 = A).

## Non-Goals

- No persistent battery readout, no low-battery polling, no on-demand reveal (Q2 ruled out C and D).
- No device name in UI (Q3 = C — icon + battery only).
- No support for non-audio peripherals (mice, keyboards, watches) in v1.
- No multi-device queue UI; latest connect wins (Q4 = B).
- No L/R/case breakdown shown; AirPods battery collapses to lowest non-nil for the ring.

## Architecture

```
+----------------------------+        +-----------------------------+
| BluetoothMonitorService    |        | SystemHUDService            |
| (IOBluetooth notifications)|        | (existing volume/brightness)|
+--------------+-------------+        +---------------+-------------+
               |                                      |
               v                                      v
        +------+--------+   emits   +-----------------+--+
        | HudCoordinator |---------->| @Published hud:    |
        | (latest wins)  |           |   SystemHUDState?  |
        +----------------+           +---------+----------+
                                               |
                                               v
                                       +-------+--------+
                                       | NotchView      |
                                       | HudPhaseView   |
                                       +----------------+
```

**Key choice:** the existing `SystemHUDService` already owns the single `hud` slot consumed by `NotchView`. Rather than introduce a parallel publisher and reconcile race conditions in the view layer, we centralize emission through a `HudCoordinator` (or extend `SystemHUDService` to accept Bluetooth events). Latest event wins, replaces any current HUD, resets auto-dismiss timer.

`BluetoothMonitorService` lives in the app target (not `DynamicIslandCore`) because `IOBluetooth` is a macOS-only framework not appropriate for the cross-platform-friendly core package.

## Data Model

```swift
// In DynamicIslandCore (pure types, testable)
public struct BluetoothBannerPayload: Equatable, Sendable {
    public let deviceID: String           // MAC address, stable key
    public let displayName: String        // logged only; not shown
    public let iconKind: BluetoothIconKind
    public let battery: BatteryReading
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
    case single(Int)                                       // 0…100
    case airpods(left: Int?, right: Int?, caseLevel: Int?) // any may be nil
    case unknown
}

public extension BatteryReading {
    /// Single 0…1 value for ring/bar rendering. Lowest non-nil for AirPods.
    var displayLevel: Double? {
        switch self {
        case .single(let n): return Double(n) / 100.0
        case .airpods(let l, let r, let c):
            let vals = [l, r, c].compactMap { $0 }
            guard let m = vals.min() else { return nil }
            return Double(m) / 100.0
        case .unknown: return nil
        }
    }
}
```

`SystemHUDKind` extends:

```swift
enum SystemHUDKind: Equatable {
    case volume
    case brightness
    case bluetooth(BluetoothBannerPayload)
}
```

`SystemHUDState.level` and `.muted` remain on the struct but are only meaningful for `.volume` / `.brightness`. The `.bluetooth` case carries everything inside its associated payload.

## Components

### 1. `BluetoothMonitorService` (app target)

Responsibilities:
- On launch, register `IOBluetoothDevice.register(forConnectNotifications:)`.
- On each connect callback, capture `IOBluetoothDevice` reference and post a `connect` job to a serial queue.
- Filter: keep device only if Class of Device major service field reports audio (`(classOfDevice >> 21) & 0x01 != 0`) or major device class is `Audio/Video` (`0x04`). Drop non-audio.
- Resolve metadata: `addressString` → MAC, `name` → display name, `productID`/`vendorID` via `IOBluetoothDevice` getter.
- Hand off to `BluetoothBatteryReader.read(...)` and `IconResolver.resolve(...)`.
- Emit assembled `BluetoothBannerPayload` to the HUD coordinator.

Lifecycle:
- Owned by `AppDelegate` alongside `SystemHUDService`.
- Holds the `IOBluetoothUserNotification` token; releases on `deinit`.

### 2. `BluetoothBatteryReader` (testable, in core or app)

```swift
protocol BluetoothBatteryReader {
    func read(deviceID: String,
              vendorID: UInt16,
              productID: UInt16) async -> BatteryReading
}
```

Composed implementation:

1. **`IORegistryBatteryReader`** (fast path):
   - Iterates `AppleDeviceManagementHIDEventService` entries via `IOServiceMatching`.
   - Matches by `DeviceAddress` property (UUID-style or colon-MAC string normalized).
   - Reads `BatteryPercent`, `BatteryPercentLeft`, `BatteryPercentRight`, `BatteryPercentCase`.
   - If any L/R/Case present → `.airpods(...)`. Else if `BatteryPercent` present → `.single(n)`. Else returns `nil` so the composer can fall through.
   - Synchronous, ~ms.

2. **`SystemProfilerBatteryReader`** (fallback):
   - Spawns `/usr/sbin/system_profiler SPBluetoothDataType -json -timeout 2` on a background queue.
   - JSON-decodes, locates the device entry by MAC (case-insensitive).
   - Pulls `device_batteryLevelMain` / `device_batteryLevelLeft` / `_Right` / `_Case`.
   - 30-second result cache keyed by MAC to absorb rapid reconnect bursts.
   - Bounded concurrency: at most one in-flight `system_profiler` process at a time.

3. **`CompositeBatteryReader`** (orchestrator):
   - Calls registry reader first.
   - If result is non-`unknown`, returns immediately.
   - If `unknown`, kicks off async fallback. Returns `unknown` to the caller now so banner can render without delay; when the fallback resolves, calls a closure to update the in-flight banner state in place.

### 3. `IconResolver`

Pure function from `(vendorID, productID, deviceClass)` → `BluetoothIconKind`.

- Vendor `0x004C` (Apple) + known product IDs → AirPods variants:
  - `0x200E`, `0x200F` → `.airpods` (gen 1/2)
  - `0x2013`, `0x2014` → `.airpods` (gen 3)
  - `0x200B`, `0x200C` → `.airpodsPro`
  - `0x2024` → `.airpodsPro` (pro 2)
  - `0x200A` → `.airpodsMax`
  - Unknown Apple audio PID → `.airpods` as a safe default.
- Vendor `0x05AC` Beats variants (subset) → `.beatsHeadphones` / `.beatsEarbuds` based on PID family ranges; unknown Beats PID → `.beatsHeadphones`.
- Else, derive from CoD device sub-class:
  - Headphones (sub-class `0x06`) / hands-free (`0x08`) → `.genericHeadphones`
  - Loudspeaker (`0x05`) / car audio (`0x08`) → `.genericSpeaker`
  - Fallback → `.genericHeadphones`

Product-ID table is a small static dictionary; entries can be appended without touching call sites.

### 4. `HudPhaseView` extension

`HudPhaseView` gains a switch over `state.kind`:

- `.volume` / `.brightness`: existing layout, unchanged.
- `.bluetooth(payload)`: replaces the bar with a battery ring rendered from `payload.battery.displayLevel`. Left icon resolves from `payload.iconKind` to:
  - `.airpods` → `airpods` SF Symbol
  - `.airpodsPro` → `airpods.pro`
  - `.airpodsMax` → `airpods.max`
  - `.beatsHeadphones` → `beats.headphones`
  - `.beatsEarbuds` → `beats.earbuds`
  - `.genericHeadphones` → `headphones`
  - `.genericSpeaker` → `hifispeaker.fill`

When `displayLevel` is nil (`.unknown`), the right slot is omitted entirely — the banner shows just the icon centered. No empty ring, no placeholder. Keeps the visual clean when fallback hasn't resolved.

### 5. HUD slot wiring

`SystemHUDService` exposes a new method:

```swift
func showBluetoothBanner(_ payload: BluetoothBannerPayload)
```

It reuses the existing `show(_:)` private path, which cancels any pending hide and schedules dismissal at 1.5s. **Decision:** bump dismissal to 3.0s for `.bluetooth` to match Q2 ("banner ~3s"); keep 1.5s for volume/brightness. Implementation: branch on `state.kind` inside `show(_:)`.

## Data Flow (connect event)

```
IOBluetooth notification
    └─ BluetoothMonitorService onConnect(device)
         ├─ filter: audio? else drop
         ├─ resolve: name, mac, vid, pid
         ├─ icon = IconResolver.resolve(vid, pid, cod)
         ├─ battery = await CompositeBatteryReader.read(mac, vid, pid)
         │     ├─ IORegistry hit → return reading
         │     └─ miss → kick off system_profiler async, return .unknown now
         ├─ payload = BluetoothBannerPayload(...)
         └─ SystemHUDService.showBluetoothBanner(payload)
              └─ NotchView re-renders HudPhaseView with .bluetooth case
                  └─ 3s timer dismisses
              (if async fallback resolves before dismiss, payload is replaced
               with updated battery; banner re-renders without resetting timer)
```

## Error Handling and Edge Cases

- **Battery unavailable:** banner still shows; ring renders empty/dashed. Logged at debug level.
- **`system_profiler` failure or timeout:** caught, treated as `.unknown`; cache is *not* populated so a later connect will retry.
- **Rapid reconnects (same MAC within 5s):** debounced — second connect inside the window does not re-emit. Prevents banner spam from flaky pairings.
- **Banner conflict with active volume/brightness HUD:** latest event wins per Q4. Connect during a volume HUD replaces it; if user keeps tapping volume, the volume HUD will replace the bluetooth banner — acceptable.
- **App not yet launched at connect time:** `IOBluetoothDevice.pairedDevices()` enumerated at launch; already-connected devices are *not* shown retroactively. Only post-launch connects fire the banner.
- **Multiple simultaneous connects:** events serialized through the monitor's queue; latest wins.
- **Permissions:** `IOBluetooth` requires no special TCC entitlement. `system_profiler` requires none. No regression vs. the AX permission flow used by the media-key tap.
- **Sandbox:** if the app ever ships sandboxed, `system_profiler` spawn will need re-evaluation (entitlement or alternative). Out of scope for v1.

## Testing

In `DynamicIslandCoreTests`:

- `BatteryReadingTests`:
  - `displayLevel` returns lowest non-nil for `.airpods`.
  - `.unknown` returns nil.
  - `.single(n)` returns `n / 100`.
- `IconResolverTests`:
  - Apple vendor + known PIDs map to expected variants.
  - Unknown Apple audio PID falls back to `.airpods`.
  - Non-Apple audio CoD subclasses map to generic kinds.
- `CompositeBatteryReaderTests` (using mock readers):
  - Registry hit → fallback never invoked.
  - Registry miss → fallback invoked, in-flight callback receives updated reading.
  - Fallback timeout → final value is `.unknown`, no crash.

In app target (manual / smoke):
- Connect AirPods Pro → banner shows AirPods Pro icon + correct battery within 1s.
- Connect Bose QC → banner shows generic headphones; battery may be `.unknown` until fallback resolves, then ring fills in.
- Bluetooth disabled in the middle of a connect → no crash; banner either renders with `.unknown` or never shows.

## Out of Scope (v1)

- Per-pod L/R/case display (data is captured but not rendered).
- Disconnect banners.
- Low-battery alerts.
- Hover-to-reveal battery on already-connected device.
- Non-audio peripherals.
- Sandboxed distribution.

## Open Implementation Decisions (deferred to plan)

- Whether `HudCoordinator` is a new type or `SystemHUDService` simply gains a method. Leaning toward the latter — fewer moving parts, single source of truth already exists.
- Whether AirPods PID table lives in `IconResolver.swift` or a separate `AirPodsCatalog.swift`. Cosmetic.
