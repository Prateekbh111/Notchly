# Notch Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom NotchShape with `UnevenRoundedRectangle`, finalize phase dimensions, wire the output picker to CoreAudio, and propagate `MRMediaRemoteSendCommand` results so failed commands log without surfacing UI errors.

**Architecture:** Pure logic stays in `DynamicIslandCore` (protocol returns `Bool`). AppKit/SwiftUI glue in the app target swaps `NotchShape` → `UnevenRoundedRectangle` and adds a CoreAudio-backed `OutputPickerController` invoked from a SwiftUI button.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, CoreAudio (`AudioObjectGetPropertyData`, `kAudioHardwarePropertyDefaultOutputDevice`), XCTest, Xcode 15+ (macOS 14+).

**Reference spec:** `docs/superpowers/specs/2026-04-29-notch-polish-design.md`

---

## File Structure

**Modified in `DynamicIslandCore` (Swift Package):**

```
DynamicIslandCore/
├── Sources/DynamicIslandCore/
│   ├── MediaRemoteBridge.swift            # send(_:) returns Bool now
│   ├── TransportController.swift          # discardable Bool plumbed through
│   └── NotchShape.swift                   # DELETE
└── Tests/DynamicIslandCoreTests/
    ├── NowPlayingServiceTests.swift       # FakeBridge.send returns Bool
    ├── TransportControllerTests.swift     # add return-value test
    └── NotchShapeTests.swift              # DELETE
```

**Modified in Xcode app target:**

```
Dynamic island/
├── Notch/
│   ├── NotchBackground.swift              # UnevenRoundedRectangle
│   └── NotchView.swift                    # new dimensions per phase
├── Phases/
│   └── ExpandedPhaseView.swift            # output picker → menu
└── Media/
    ├── RealMediaRemoteBridge.swift        # send returns Bool
    └── OutputPickerController.swift       # NEW — CoreAudio device list + menu
```

---

## Task 1: Change `MediaRemoteBridge.send(_:)` to return `Bool`

**Files:**
- Modify: `DynamicIslandCore/Sources/DynamicIslandCore/MediaRemoteBridge.swift`

- [ ] **Step 1: Update the protocol signature**

In `DynamicIslandCore/Sources/DynamicIslandCore/MediaRemoteBridge.swift`, change the protocol to:

```swift
public protocol MediaRemoteBridge: AnyObject, Sendable {
    var onChange: (@Sendable (NowPlayingSnapshot) -> Void)? { get set }
    func start()
    func stop()
    @discardableResult
    func send(_ command: MediaCommand) -> Bool
}
```

The `@discardableResult` attribute lets call sites that don't care about the return value continue to compile unchanged.

- [ ] **Step 2: Build the package — expected to fail**

Run: `cd DynamicIslandCore && swift build 2>&1 | tail -10`
Expected: build fails because `FakeBridge.send` and `TransportController.bridge.send(_:)` no longer match the protocol.

- [ ] **Step 3: Update `FakeBridge.send` in tests**

In `DynamicIslandCore/Tests/DynamicIslandCoreTests/NowPlayingServiceTests.swift`, change:

```swift
func send(_ command: MediaCommand) { sentCommands.append(command) }
```

to:

```swift
func send(_ command: MediaCommand) -> Bool { sentCommands.append(command); return true }
```

- [ ] **Step 4: Run all package tests**

Run: `cd DynamicIslandCore && swift test 2>&1 | tail -10`
Expected: all 14 tests pass.

- [ ] **Step 5: Commit**

```bash
git add DynamicIslandCore
git commit -m "feat: MediaRemoteBridge.send returns Bool"
```

---

## Task 2: Plumb the Bool through `TransportController`

**Files:**
- Modify: `DynamicIslandCore/Sources/DynamicIslandCore/TransportController.swift`
- Modify: `DynamicIslandCore/Tests/DynamicIslandCoreTests/TransportControllerTests.swift`

- [ ] **Step 1: Add a failing test for return value**

In `TransportControllerTests.swift`, append:

```swift
func test_playPauseReturnsBridgeBool() {
    let bridge = FakeBridge()
    let controller = TransportController(bridge: bridge)
    let result = controller.playPause()
    XCTAssertTrue(result)
}
```

- [ ] **Step 2: Run, verify fails to compile**

Run: `cd DynamicIslandCore && swift test --filter TransportControllerTests 2>&1 | tail -10`
Expected: fail — `playPause()` returns `Void`.

- [ ] **Step 3: Update controller**

Replace the body of `DynamicIslandCore/Sources/DynamicIslandCore/TransportController.swift` with:

```swift
import Foundation

public final class TransportController: Sendable {
    private let bridge: MediaRemoteBridge

    public init(bridge: MediaRemoteBridge) {
        self.bridge = bridge
    }

    @discardableResult public func playPause() -> Bool { bridge.send(.togglePlayPause) }
    @discardableResult public func next() -> Bool { bridge.send(.next) }
    @discardableResult public func previous() -> Bool { bridge.send(.previous) }
    @discardableResult public func toggleShuffle() -> Bool { bridge.send(.toggleShuffle) }
}
```

- [ ] **Step 4: Run tests, confirm pass**

Run: `cd DynamicIslandCore && swift test 2>&1 | tail -10`
Expected: 15/15 pass (the existing 14 + the new return-value test).

- [ ] **Step 5: Commit**

```bash
git add DynamicIslandCore
git commit -m "feat: TransportController returns command-accepted Bool"
```

---

## Task 3: `RealMediaRemoteBridge.send` returns the actual Bool, logs on false

**Files:**
- Modify: `Dynamic island/Media/RealMediaRemoteBridge.swift`

- [ ] **Step 1: Replace `send(_:)` body**

In `Dynamic island/Media/RealMediaRemoteBridge.swift`, change:

```swift
func send(_ command: MediaCommand) {
    _ = sendCommand?(command.rawValue, nil)
}
```

to:

```swift
func send(_ command: MediaCommand) -> Bool {
    let result = sendCommand?(command.rawValue, nil) ?? false
    if !result {
        NSLog("[MR] send(%d) returned false (no active client?)", command.rawValue)
    }
    return result
}
```

- [ ] **Step 2: Build the app target**

Run: `xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Media/RealMediaRemoteBridge.swift"
git commit -m "feat: RealMediaRemoteBridge propagates send result with diagnostic log"
```

---

## Task 4: Delete legacy `NotchShape`

**Files:**
- Delete: `DynamicIslandCore/Sources/DynamicIslandCore/NotchShape.swift`
- Delete: `DynamicIslandCore/Tests/DynamicIslandCoreTests/NotchShapeTests.swift`

- [ ] **Step 1: Delete both files**

```bash
rm "DynamicIslandCore/Sources/DynamicIslandCore/NotchShape.swift"
rm "DynamicIslandCore/Tests/DynamicIslandCoreTests/NotchShapeTests.swift"
```

- [ ] **Step 2: Build & test**

Run: `cd DynamicIslandCore && swift test 2>&1 | tail -10`
Expected: 13 tests pass (was 15, lost 2 from NotchShapeTests).

- [ ] **Step 3: Commit**

```bash
git add DynamicIslandCore
git commit -m "chore: remove legacy NotchShape (replaced by UnevenRoundedRectangle in app target)"
```

---

## Task 5: Replace `NotchShape` with `UnevenRoundedRectangle` in `NotchBackground`

**Files:**
- Modify: `Dynamic island/Notch/NotchBackground.swift`

- [ ] **Step 1: Rewrite the file**

Replace the entire content of `Dynamic island/Notch/NotchBackground.swift` with:

```swift
import SwiftUI
import AppKit

struct NotchBackground: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat

    init(cornerRadius: CGFloat, topCornerRadius: CGFloat = 8) {
        self.bottomCornerRadius = cornerRadius
        self.topCornerRadius = topCornerRadius
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: topCornerRadius,
            bottomLeadingRadius: bottomCornerRadius,
            bottomTrailingRadius: bottomCornerRadius,
            topTrailingRadius: topCornerRadius,
            style: .continuous
        )
        shape
            .fill(.black.opacity(0.92))
            .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
    }
}
```

The `import DynamicIslandCore` from the previous version is removed because `UnevenRoundedRectangle` is a SwiftUI built-in.

- [ ] **Step 2: Build the app**

Run: `xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Notch/NotchBackground.swift"
git commit -m "feat: NotchBackground uses UnevenRoundedRectangle"
```

---

## Task 6: Update `NotchView` phase dimensions and per-corner radii

**Files:**
- Modify: `Dynamic island/Notch/NotchView.swift`

- [ ] **Step 1: Replace the `shapeSize` and `cornerRadii` computed properties**

In `Dynamic island/Notch/NotchView.swift`, replace the existing `shapeSize` and `cornerRadii` computed properties with:

```swift
private var shapeSize: CGSize {
    switch phase {
    case .idle:
        return CGSize(width: notchSize.width, height: 0.1)
    case .compact:
        return CGSize(width: 200, height: 30)
    case .expanded:
        return CGSize(width: 380, height: 180)
    }
}

private var cornerRadii: (top: CGFloat, bottom: CGFloat) {
    switch phase {
    case .idle: return (0, 0)
    case .compact: return (4, 8)
    case .expanded: return (8, 32)
    }
}
```

These match the spec table exactly.

- [ ] **Step 2: Build the app**

Run: `xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Notch/NotchView.swift"
git commit -m "feat: phase dimensions and corner radii per polish spec"
```

---

## Task 7: `OutputPickerController` — CoreAudio device enumeration + menu

**Files:**
- Create: `Dynamic island/Media/OutputPickerController.swift`

- [ ] **Step 1: Create the file**

Create `Dynamic island/Media/OutputPickerController.swift` with this content:

```swift
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
```

- [ ] **Step 2: Build the app**

Run: `xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED. (`PBXFileSystemSynchronizedRootGroup` auto-picks up the new file.)

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Media/OutputPickerController.swift"
git commit -m "feat: OutputPickerController for CoreAudio device selection"
```

---

## Task 8: Wire output picker button in `ExpandedPhaseView`

**Files:**
- Modify: `Dynamic island/Phases/ExpandedPhaseView.swift`

- [ ] **Step 1: Add an `OutputPickerController` reference and trigger menu on button tap**

Replace the entire content of `Dynamic island/Phases/ExpandedPhaseView.swift` with:

```swift
import SwiftUI
import AppKit
import DynamicIslandCore

struct ExpandedPhaseView: View {
    let snapshot: NowPlayingSnapshot
    let transport: TransportController
    let artNamespace: Namespace.ID

    private let outputPicker = OutputPickerController()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ArtworkView(data: snapshot.track?.artwork)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .matchedGeometryEffect(id: "artwork", in: artNamespace)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.track?.title ?? "Not Playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if let artist = snapshot.track?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: "waveform")
                    .foregroundStyle(.white.opacity(0.7))
            }

            ScrubberView(elapsed: snapshot.elapsed, duration: snapshot.track?.duration ?? 0)

            HStack(spacing: 24) {
                Button(action: { transport.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                }
                Button(action: { transport.previous() }) {
                    Image(systemName: "backward.fill")
                }
                Button(action: { transport.playPause() }) {
                    Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                }
                Button(action: { transport.next() }) {
                    Image(systemName: "forward.fill")
                }
                OutputPickerButton(controller: outputPicker)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 360)
    }
}

private struct OutputPickerButton: NSViewRepresentable {
    let controller: OutputPickerController

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Audio output")
        button.contentTintColor = .white
        button.target = context.coordinator
        button.action = #selector(Coordinator.click(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    @MainActor
    final class Coordinator: NSObject {
        let controller: OutputPickerController
        init(controller: OutputPickerController) { self.controller = controller }

        @objc func click(_ sender: NSButton) {
            let location = NSPoint(x: 0, y: sender.bounds.height + 4)
            controller.presentMenu(at: location, in: sender)
        }
    }
}

private struct ScrubberView: View {
    let elapsed: TimeInterval
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(.white).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)

            HStack {
                Text(format(elapsed))
                Spacer()
                Text("-" + format(max(0, duration - elapsed)))
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, elapsed / duration)))
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
```

The four transport `Button` actions wrap `transport.toggleShuffle()` / `previous()` / `playPause()` / `next()` in closures because those methods now return `Bool` and SwiftUI's `Button(action:)` wants a `Void`-returning closure. The output picker is rendered as an `NSViewRepresentable` wrapping `NSButton` so we can call `controller.presentMenu` from the AppKit `target/action` pair.

- [ ] **Step 2: Build the app**

Run: `xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Phases/ExpandedPhaseView.swift"
git commit -m "feat: wire output picker button to NSMenu"
```

---

## Task 9: Manual verification

**Files:** none — runtime check.

- [ ] **Step 1: Run the app**

Open the project in Xcode, ⌘R. Confirm:

1. Idle (no media, no hover): only the hardware notch is visible (no software shape).
2. Hover near notch: card grows from notch downward with spring animation. Top edge sits at screen top, merging with the notch hardware.
3. Card has top corners ~8pt and bottom corners ~32pt.
4. Subtle haptic on expand.
5. Click play / pause / next / prev → media app reacts.
6. Click output picker (laptop icon) → menu pops up listing audio outputs. Current default has a checkmark. Selecting a different output switches the system default audio.
7. If no media client active (idle phase shouldn't even show buttons; expanded "Not Playing" with hover and no media): clicking play does nothing visually. Console shows `[MR] send(2) returned false` line.
8. YouTube Music in Chrome: with sandbox disabled and polling on, metadata appears within 2s.

- [ ] **Step 2: If everything works, commit a verification log**

```bash
echo "Polish manual verification 2026-04-29: all 8 checks pass on $(uname -m) macOS $(sw_vers -productVersion)" \
  >> docs/superpowers/plans/2026-04-29-notch-polish-verification.md
git add docs/superpowers/plans/2026-04-29-notch-polish-verification.md
git commit -m "docs: log polish verification pass"
```

---

## Self-Review Notes

- **Spec coverage:** all sections of the polish spec (shape via `UnevenRoundedRectangle`, dimensions table, animation unchanged, hover unchanged, mouse clicks with output picker, error handling with logged `Bool`, edge effect unchanged, file changes list) are mapped 1:1 to Tasks 1-8.
- **No placeholders:** every step has exact code; no "TODO" or "fill in".
- **Type consistency:** `MediaRemoteBridge.send(_:) -> Bool` is established in Task 1 and consumed by Task 2 (TransportController) and Task 3 (RealMediaRemoteBridge). `FakeBridge.send` updated in Task 1. `OutputPickerController.presentMenu(at:in:)` defined in Task 7 and called from Task 8.
- **Tests:** Task 1 + 2 keep the SPM test suite green at 13 (after dropping NotchShape's 2 tests); Task 2 adds 1 return-value test bringing the count to 14. Task 4 deletes NotchShape's 2 tests, ending at 13. (The exact final count is 13; the plan documents this transition explicitly.)
