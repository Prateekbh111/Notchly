# Source-Agnostic Now Playing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-app AppleScript fallback with a single source-agnostic now-playing pipeline driven by `mediaremote-adapter`, and add a `titleBanner` phase that auto-expands the notch on track change to match the reference recording.

**Architecture:** A bundled helper binary registers as a system MediaRemote client and streams NDJSON now-playing events on stdout. The host app reads the stream, maps it to `NowPlayingSnapshot`, and drives a four-state phase machine (idle / compact / titleBanner / expanded). The titleBanner phase is triggered by a recent (track) change within 4 seconds and renders a horizontal pill with a scrolling marquee title and an animated EQ glyph.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, XCTest, `Foundation.Process`/`Pipe` for helper IPC, `Combine` (existing). Helper: ungive/mediaremote-adapter (MIT, prebuilt binary).

**Spec:** `docs/superpowers/specs/2026-05-01-source-agnostic-now-playing-design.md`

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `Vendor/mediaremote-adapter/mediaremote-adapter` | Pre-built helper binary (committed). |
| `Vendor/mediaremote-adapter/LICENSE` | Upstream MIT license. |
| `Vendor/mediaremote-adapter/README.md` | One-paragraph note: where the binary came from, version, how to refresh. |
| `Dynamic island/Media/AdapterPayload.swift` | `Codable` envelope for helper NDJSON. |
| `Dynamic island/Media/MediaRemoteAdapterBridge.swift` | `MediaRemoteBridge` impl that drives the helper. |
| `Dynamic island/Media/HelperProcess.swift` | Tiny protocol over `Process` so the bridge is unit-testable. |
| `Dynamic island/Notch/EQGlyphView.swift` | 3-bar animated equalizer glyph. |
| `Dynamic island/Notch/MarqueeText.swift` | Horizontally scrolling text. |
| `Dynamic island/Phases/TitleBannerView.swift` | Horizontal banner phase (artwork · marquee · EQ). |
| `DynamicIslandCore/Tests/DynamicIslandCoreTests/PhaseReducerTitleBannerTests.swift` | Truth-table tests for new reducer signature. |
| `DynamicIslandCore/Tests/DynamicIslandCoreTests/NowPlayingServiceRecentChangeTests.swift` | Tests for `lastTrackChangeAt` / `recentChange`. |
| `Dynamic islandTests/MediaRemoteAdapterBridgeTests.swift` | Bridge integration tests via fake `HelperProcess`. |
| `Dynamic islandTests/AdapterPayloadTests.swift` | Decoder tests for canned NDJSON. |

### Modified files

| Path | Change |
|---|---|
| `DynamicIslandCore/Sources/DynamicIslandCore/Phase.swift` | Add `.titleBanner` case. |
| `DynamicIslandCore/Sources/DynamicIslandCore/PhaseReducer.swift` | New signature including `recentChange`. |
| `DynamicIslandCore/Sources/DynamicIslandCore/NowPlayingService.swift` | Track `lastTrackChangeAt`; expose `recentChange(now:)`. |
| `DynamicIslandCore/Tests/DynamicIslandCoreTests/PhaseReducerTests.swift` | Migrate to new reducer signature. |
| `Dynamic island/App/AppDelegate.swift` | Swap `RealMediaRemoteBridge` → `MediaRemoteAdapterBridge`. |
| `Dynamic island/Notch/NotchView.swift` | Pass `recentChange` to reducer; add `.titleBanner` arm in `shapeSize`, `cornerRadii`, `content`. |
| `Dynamic island/Phases/CompactPhaseView.swift` | Replace inline `EQBars` with shared `EQGlyphView`. |
| `Dynamic island.xcodeproj/project.pbxproj` | (a) Drop `INFOPLIST_KEY_NSAppleEventsUsageDescription`; (b) add Copy Files build phase for helper; (c) add new `.swift` files to membership. |

### Deleted files

| Path | Reason |
|---|---|
| `Dynamic island/Media/RealMediaRemoteBridge.swift` | Replaced. |
| `Dynamic island/Media/AppleScriptNowPlaying.swift` | No fallback path needed. |

---

## Task 1 — Vendor the helper binary

**Files:**
- Create: `Vendor/mediaremote-adapter/mediaremote-adapter` (binary)
- Create: `Vendor/mediaremote-adapter/LICENSE`
- Create: `Vendor/mediaremote-adapter/README.md`

- [ ] **Step 1: Create vendor directory**

```bash
mkdir -p "Vendor/mediaremote-adapter"
```

- [ ] **Step 2: Download upstream release binary**

Download the latest universal release binary from `https://github.com/ungive/mediaremote-adapter/releases`. Choose the asset named like `mediaremote-adapter-vX.Y.Z-macos-universal.tar.gz`.

```bash
cd Vendor/mediaremote-adapter
curl -fLO "https://github.com/ungive/mediaremote-adapter/releases/latest/download/mediaremote-adapter-macos-universal.tar.gz"
tar -xzf mediaremote-adapter-macos-universal.tar.gz
mv mediaremote-adapter-macos-universal/mediaremote-adapter ./mediaremote-adapter
mv mediaremote-adapter-macos-universal/LICENSE ./LICENSE
rm -rf mediaremote-adapter-macos-universal mediaremote-adapter-macos-universal.tar.gz
chmod +x mediaremote-adapter
```

If the asset name differs, list the release page and adjust. The end state is exactly: `Vendor/mediaremote-adapter/mediaremote-adapter` (executable) and `Vendor/mediaremote-adapter/LICENSE`.

- [ ] **Step 3: Verify binary launches and streams JSON**

```bash
./Vendor/mediaremote-adapter/mediaremote-adapter stream
```

Expected: while music plays anywhere on the system, lines of JSON print to stdout. Press Ctrl-C to stop. If nothing prints, start a track in any app first.

Capture one printed line into `Vendor/mediaremote-adapter/sample-payload.json` — used by Task 4 tests.

```bash
./Vendor/mediaremote-adapter/mediaremote-adapter stream | head -n 1 > Vendor/mediaremote-adapter/sample-payload.json
```

- [ ] **Step 4: Write the README**

Write to `Vendor/mediaremote-adapter/README.md`:

```markdown
# mediaremote-adapter

Source: https://github.com/ungive/mediaremote-adapter (MIT)

This binary registers as a macOS MediaRemote client and prints now-playing
events as NDJSON on stdout. We bundle it as `Resources/mediaremote-adapter`
so the host app can spawn it without per-app AppleEvents prompts.

## Refreshing

1. Download the latest universal release from GitHub Releases.
2. Replace `mediaremote-adapter` and `LICENSE` in this directory.
3. `chmod +x mediaremote-adapter`.
4. Re-run the integration check in `Dynamic islandTests/MediaRemoteAdapterBridgeTests.swift`.
```

- [ ] **Step 5: Commit**

```bash
git add Vendor/mediaremote-adapter
git commit -m "vendor: add mediaremote-adapter helper binary"
```

---

## Task 2 — Add Copy Files build phase for the helper

**Files:**
- Modify: `Dynamic island.xcodeproj/project.pbxproj`

- [ ] **Step 1: Open Xcode and add the binary as a project file reference**

In Xcode: File → Add Files to "Dynamic island"… → select `Vendor/mediaremote-adapter/mediaremote-adapter`. Uncheck "Copy items if needed". For "Add to targets", check the `Dynamic island` app target only. This creates a `PBXFileReference` and a build file membership.

- [ ] **Step 2: Add a Copy Files build phase**

In Xcode: select the `Dynamic island` target → Build Phases → `+` → New Copy Files Phase. Configure:

- Destination: `Resources`
- Subpath: (empty)
- Drag the `mediaremote-adapter` file reference into the phase.

Rename the phase to "Copy Helper Binary" (double-click the header).

Drag the new phase below "Compile Sources" and above "Copy Bundle Resources".

- [ ] **Step 3: Verify the binary lands inside the .app**

```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug -derivedDataPath build clean build 2>&1 | tail -20
ls build/Build/Products/Debug/Dynamic\ island.app/Contents/Resources/mediaremote-adapter
```

Expected: file exists and is executable.

- [ ] **Step 4: Commit**

```bash
git add "Dynamic island.xcodeproj/project.pbxproj"
git commit -m "build: copy mediaremote-adapter into app bundle Resources"
```

---

## Task 3 — `AdapterPayload` codable envelope

**Files:**
- Create: `Dynamic island/Media/AdapterPayload.swift`
- Test: `Dynamic islandTests/AdapterPayloadTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Dynamic islandTests/AdapterPayloadTests.swift`:

```swift
import XCTest
@testable import Dynamic_island

final class AdapterPayloadTests: XCTestCase {
    func test_decodesPlayingEnvelope() throws {
        let json = """
        {"type":"playing","payload":{"bundleIdentifier":"com.spotify.client","title":"T","artist":"A","album":"AL","duration":210.0,"elapsedTime":12.3,"playbackRate":1.0,"artworkData":"YWJjZA==","artworkMimeType":"image/jpeg"}}
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(AdapterEnvelope.self, from: json)

        XCTAssertEqual(payload.type, "playing")
        XCTAssertEqual(payload.payload.title, "T")
        XCTAssertEqual(payload.payload.artist, "A")
        XCTAssertEqual(payload.payload.album, "AL")
        XCTAssertEqual(payload.payload.duration, 210.0)
        XCTAssertEqual(payload.payload.elapsedTime, 12.3)
        XCTAssertEqual(payload.payload.playbackRate, 1.0)
        XCTAssertEqual(payload.payload.artworkData, Data([0x61, 0x62, 0x63, 0x64]))
    }

    func test_decodesStoppedEnvelope() throws {
        let json = """
        {"type":"stopped","payload":{}}
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(AdapterEnvelope.self, from: json)

        XCTAssertEqual(payload.type, "stopped")
        XCTAssertNil(payload.payload.title)
    }

    func test_missingArtworkDecodesAsNil() throws {
        let json = """
        {"type":"playing","payload":{"title":"T","artist":"A","duration":10,"elapsedTime":0,"playbackRate":1.0}}
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(AdapterEnvelope.self, from: json)
        XCTAssertNil(payload.payload.artworkData)
    }
}
```

- [ ] **Step 2: Run test, verify failure**

Run: `xcodebuild test -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -only-testing:"Dynamic islandTests/AdapterPayloadTests"`
Expected: compile failure — `AdapterEnvelope` undefined.

- [ ] **Step 3: Implement `AdapterPayload.swift`**

Create `Dynamic island/Media/AdapterPayload.swift`:

```swift
import Foundation

struct AdapterEnvelope: Decodable, Equatable {
    let type: String
    let payload: AdapterPayload
}

struct AdapterPayload: Decodable, Equatable {
    let bundleIdentifier: String?
    let title: String?
    let artist: String?
    let album: String?
    let duration: TimeInterval?
    let elapsedTime: TimeInterval?
    let playbackRate: Double?
    let artworkData: Data?
    let artworkMimeType: String?

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case title
        case artist
        case album
        case duration
        case elapsedTime
        case playbackRate
        case artworkData
        case artworkMimeType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try c.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        album = try c.decodeIfPresent(String.self, forKey: .album)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration)
        elapsedTime = try c.decodeIfPresent(TimeInterval.self, forKey: .elapsedTime)
        playbackRate = try c.decodeIfPresent(Double.self, forKey: .playbackRate)
        artworkMimeType = try c.decodeIfPresent(String.self, forKey: .artworkMimeType)

        if let base64 = try c.decodeIfPresent(String.self, forKey: .artworkData) {
            artworkData = Data(base64Encoded: base64)
        } else {
            artworkData = nil
        }
    }
}
```

- [ ] **Step 4: Add file to target and rerun tests**

Make sure the new `AdapterPayload.swift` is checked into the `Dynamic island` target (Xcode → File Inspector → Target Membership). Same for the test file in the test target.

Run: `xcodebuild test -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -only-testing:"Dynamic islandTests/AdapterPayloadTests"`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add "Dynamic island/Media/AdapterPayload.swift" "Dynamic islandTests/AdapterPayloadTests.swift" "Dynamic island.xcodeproj/project.pbxproj"
git commit -m "feat(media): AdapterPayload + envelope decoder"
```

---

## Task 4 — `HelperProcess` protocol for testability

**Files:**
- Create: `Dynamic island/Media/HelperProcess.swift`

- [ ] **Step 1: Write the protocol and concrete impl**

Create `Dynamic island/Media/HelperProcess.swift`:

```swift
import Foundation

protocol HelperProcess: AnyObject {
    var onStdoutLine: ((String) -> Void)? { get set }
    var onTermination: ((Int32) -> Void)? { get set }
    func launch() throws
    func terminate()
}

final class SystemHelperProcess: HelperProcess {
    var onStdoutLine: ((String) -> Void)?
    var onTermination: ((Int32) -> Void)?

    private let executableURL: URL
    private let arguments: [String]
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var lineBuffer = Data()

    init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }

    func launch() throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        self.stdoutPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.handleData(handle.availableData)
        }

        process.terminationHandler = { [weak self] proc in
            self?.onTermination?(proc.terminationStatus)
        }

        try process.run()
        self.process = process
    }

    func terminate() {
        process?.terminate()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
    }

    private func handleData(_ data: Data) {
        guard !data.isEmpty else { return }
        lineBuffer.append(data)
        while let newlineIndex = lineBuffer.firstIndex(of: 0x0A) {
            let lineData = lineBuffer.subdata(in: 0..<newlineIndex)
            lineBuffer.removeSubrange(0...newlineIndex)
            if let line = String(data: lineData, encoding: .utf8) {
                onStdoutLine?(line)
            }
        }
    }
}
```

- [ ] **Step 2: Add to target and verify it builds**

Add `HelperProcess.swift` to the `Dynamic island` target (Target Membership in File Inspector).

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Media/HelperProcess.swift" "Dynamic island.xcodeproj/project.pbxproj"
git commit -m "feat(media): HelperProcess protocol + Process-based impl"
```

---

## Task 5 — `MediaRemoteAdapterBridge` (TDD)

**Files:**
- Create: `Dynamic island/Media/MediaRemoteAdapterBridge.swift`
- Test: `Dynamic islandTests/MediaRemoteAdapterBridgeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Dynamic islandTests/MediaRemoteAdapterBridgeTests.swift`:

```swift
import XCTest
import DynamicIslandCore
@testable import Dynamic_island

final class FakeHelperProcess: HelperProcess {
    var onStdoutLine: ((String) -> Void)?
    var onTermination: ((Int32) -> Void)?
    var launchCount = 0
    var terminated = false
    var launchError: Error?

    func launch() throws {
        if let launchError { throw launchError }
        launchCount += 1
    }

    func terminate() { terminated = true }

    func emitLine(_ line: String) { onStdoutLine?(line) }
    func emitExit(_ status: Int32) { onTermination?(status) }
}

@MainActor
final class MediaRemoteAdapterBridgeTests: XCTestCase {
    func test_publishesSnapshotForPlayingEnvelope() {
        let proc = FakeHelperProcess()
        let bridge = MediaRemoteAdapterBridge(processFactory: { proc }, clock: { Date(timeIntervalSince1970: 0) })
        var captured: NowPlayingSnapshot?
        bridge.onChange = { captured = $0 }
        bridge.start()

        proc.emitLine(#"{"type":"playing","payload":{"title":"Song","artist":"Artist","album":"AL","duration":200,"elapsedTime":12,"playbackRate":1.0}}"#)

        XCTAssertEqual(captured?.track?.title, "Song")
        XCTAssertEqual(captured?.track?.artist, "Artist")
        XCTAssertEqual(captured?.track?.album, "AL")
        XCTAssertEqual(captured?.track?.duration, 200)
        XCTAssertEqual(captured?.elapsed, 12)
        XCTAssertTrue(captured?.isPlaying ?? false)
    }

    func test_publishesEmptyForStoppedEnvelope() {
        let proc = FakeHelperProcess()
        let bridge = MediaRemoteAdapterBridge(processFactory: { proc }, clock: { Date(timeIntervalSince1970: 0) })
        var captured: NowPlayingSnapshot?
        bridge.onChange = { captured = $0 }
        bridge.start()

        proc.emitLine(#"{"type":"stopped","payload":{}}"#)

        XCTAssertEqual(captured, .empty)
    }

    func test_dropsMalformedLine() {
        let proc = FakeHelperProcess()
        let bridge = MediaRemoteAdapterBridge(processFactory: { proc }, clock: { Date(timeIntervalSince1970: 0) })
        var callCount = 0
        bridge.onChange = { _ in callCount += 1 }
        bridge.start()

        proc.emitLine("garbage")
        XCTAssertEqual(callCount, 0)
    }

    func test_relaunchesOnAbnormalExit() {
        var processes: [FakeHelperProcess] = [FakeHelperProcess(), FakeHelperProcess(), FakeHelperProcess()]
        let bridge = MediaRemoteAdapterBridge(
            processFactory: { processes.removeFirst() },
            relaunchDelay: 0,
            clock: { Date(timeIntervalSince1970: 0) }
        )
        bridge.start()
        let firstProc = bridge.currentProcessForTesting as! FakeHelperProcess
        XCTAssertEqual(firstProc.launchCount, 1)

        firstProc.emitExit(1)

        let secondProc = bridge.currentProcessForTesting as! FakeHelperProcess
        XCTAssertEqual(secondProc.launchCount, 1)
    }

    func test_stopsRelaunchingAfterCrashLoop() {
        var processes: [FakeHelperProcess] = (0..<6).map { _ in FakeHelperProcess() }
        let baseDate = Date(timeIntervalSince1970: 0)
        var nowOffset: TimeInterval = 0
        let bridge = MediaRemoteAdapterBridge(
            processFactory: { processes.removeFirst() },
            relaunchDelay: 0,
            clock: { baseDate.addingTimeInterval(nowOffset) }
        )
        var emptyCount = 0
        bridge.onChange = { snap in if snap == .empty { emptyCount += 1 } }
        bridge.start()

        for _ in 0..<3 {
            (bridge.currentProcessForTesting as! FakeHelperProcess).emitExit(1)
            nowOffset += 1
        }

        XCTAssertNil(bridge.currentProcessForTesting)
        XCTAssertGreaterThan(emptyCount, 0)
    }
}
```

- [ ] **Step 2: Run, verify failure**

Run: `xcodebuild test -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -only-testing:"Dynamic islandTests/MediaRemoteAdapterBridgeTests"`
Expected: compile failure — `MediaRemoteAdapterBridge` undefined.

- [ ] **Step 3: Implement the bridge**

Create `Dynamic island/Media/MediaRemoteAdapterBridge.swift`:

```swift
import Foundation
import DynamicIslandCore

final class MediaRemoteAdapterBridge: MediaRemoteBridge, @unchecked Sendable {
    var onChange: (@Sendable (NowPlayingSnapshot) -> Void)?

    private let processFactory: () -> HelperProcess
    private let relaunchDelay: TimeInterval
    private let clock: () -> Date
    private let crashWindow: TimeInterval = 10
    private let crashLimit = 3

    private var current: HelperProcess?
    private var recentExits: [Date] = []
    private let decoder = JSONDecoder()

    var currentProcessForTesting: HelperProcess? { current }

    init(
        processFactory: @escaping () -> HelperProcess = { defaultProcess() },
        relaunchDelay: TimeInterval = 1.0,
        clock: @escaping () -> Date = Date.init
    ) {
        self.processFactory = processFactory
        self.relaunchDelay = relaunchDelay
        self.clock = clock
    }

    func start() {
        spawn()
    }

    func stop() {
        current?.terminate()
        current = nil
    }

    @discardableResult
    func send(_ command: MediaCommand) -> Bool {
        // Helper currently does not forward transport commands.
        // Kept as a no-op so transport buttons fail silently rather than crash.
        // A future helper version can accept stdin commands.
        return false
    }

    private func spawn() {
        let proc = processFactory()
        proc.onStdoutLine = { [weak self] line in
            self?.handleLine(line)
        }
        proc.onTermination = { [weak self] status in
            self?.handleExit(status: status)
        }
        do {
            try proc.launch()
            current = proc
        } catch {
            NSLog("[MRA] launch failed: %@", String(describing: error))
            onChange?(.empty)
            current = nil
        }
    }

    private func handleLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        do {
            let env = try decoder.decode(AdapterEnvelope.self, from: data)
            onChange?(snapshot(from: env))
        } catch {
            NSLog("[MRA] drop malformed line: %@", line)
        }
    }

    private func snapshot(from env: AdapterEnvelope) -> NowPlayingSnapshot {
        guard env.type != "stopped", let title = env.payload.title, !title.isEmpty else {
            return .empty
        }
        let track = Track(
            title: title,
            artist: env.payload.artist ?? "",
            album: env.payload.album,
            artwork: env.payload.artworkData,
            duration: env.payload.duration ?? 0
        )
        let isPlaying = (env.payload.playbackRate ?? 0) > 0
        return NowPlayingSnapshot(track: track, isPlaying: isPlaying, elapsed: env.payload.elapsedTime ?? 0)
    }

    private func handleExit(status: Int32) {
        let now = clock()
        recentExits.append(now)
        recentExits = recentExits.filter { now.timeIntervalSince($0) <= crashWindow }

        if recentExits.count >= crashLimit {
            NSLog("[MRA] crash loop — giving up")
            onChange?(.empty)
            current = nil
            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + relaunchDelay) { [weak self] in
            self?.spawn()
        }
    }

    private static func defaultProcess() -> HelperProcess {
        let url = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: nil)
            ?? URL(fileURLWithPath: "/usr/bin/false")
        return SystemHelperProcess(executableURL: url, arguments: ["stream"])
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `xcodebuild test -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -only-testing:"Dynamic islandTests/MediaRemoteAdapterBridgeTests"`
Expected: 5 tests pass.

If `test_relaunchesOnAbnormalExit` is flaky because of the async dispatch, change `relaunchDelay: 0` and replace the `DispatchQueue.global().asyncAfter` with a synchronous call when `relaunchDelay == 0`. Add to `handleExit`:

```swift
if relaunchDelay == 0 {
    spawn()
} else {
    DispatchQueue.global().asyncAfter(deadline: .now() + relaunchDelay) { [weak self] in
        self?.spawn()
    }
}
```

Re-run; expect 5 passing.

- [ ] **Step 5: Commit**

```bash
git add "Dynamic island/Media/MediaRemoteAdapterBridge.swift" "Dynamic islandTests/MediaRemoteAdapterBridgeTests.swift" "Dynamic island.xcodeproj/project.pbxproj"
git commit -m "feat(media): MediaRemoteAdapterBridge with crash-loop guard"
```

---

## Task 6 — Add `.titleBanner` case to `Phase`

**Files:**
- Modify: `DynamicIslandCore/Sources/DynamicIslandCore/Phase.swift`

- [ ] **Step 1: Add case**

Replace the contents of `DynamicIslandCore/Sources/DynamicIslandCore/Phase.swift` with:

```swift
public enum Phase: Equatable, Sendable {
    case idle
    case compact
    case titleBanner
    case expanded
}
```

- [ ] **Step 2: Build the package**

Run: `swift build --package-path DynamicIslandCore`
Expected: BUILD SUCCEEDED. Existing tests still compile because the reducer hasn't changed yet.

- [ ] **Step 3: Commit**

```bash
git add DynamicIslandCore/Sources/DynamicIslandCore/Phase.swift
git commit -m "core: add Phase.titleBanner"
```

---

## Task 7 — Extend `PhaseReducer` (TDD)

**Files:**
- Modify: `DynamicIslandCore/Sources/DynamicIslandCore/PhaseReducer.swift`
- Modify: `DynamicIslandCore/Tests/DynamicIslandCoreTests/PhaseReducerTests.swift`

- [ ] **Step 1: Replace existing tests with the 8-row truth table**

Overwrite `DynamicIslandCore/Tests/DynamicIslandCoreTests/PhaseReducerTests.swift`:

```swift
import XCTest
@testable import DynamicIslandCore

final class PhaseReducerTests: XCTestCase {
    func test_idle_noMediaNoHoverNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: false, recentChange: false), .idle)
    }

    func test_idle_noMediaNoHoverYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: false, recentChange: true), .idle)
    }

    func test_compact_mediaNoHoverNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: true, recentChange: false), .compact)
    }

    func test_titleBanner_mediaNoHoverYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: false, hasMedia: true, recentChange: true), .titleBanner)
    }

    func test_expanded_hoverNoMediaNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: false, recentChange: false), .expanded)
    }

    func test_expanded_hoverNoMediaYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: false, recentChange: true), .expanded)
    }

    func test_expanded_hoverMediaNoChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: true, recentChange: false), .expanded)
    }

    func test_expanded_hoverMediaYesChange() {
        XCTAssertEqual(PhaseReducer.reduce(hovered: true, hasMedia: true, recentChange: true), .expanded)
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

Run: `swift test --package-path DynamicIslandCore --filter PhaseReducerTests`
Expected: compile failure — `reduce` does not have a `recentChange` argument.

- [ ] **Step 3: Update `PhaseReducer`**

Overwrite `DynamicIslandCore/Sources/DynamicIslandCore/PhaseReducer.swift`:

```swift
public enum PhaseReducer {
    public static func reduce(hovered: Bool, hasMedia: Bool, recentChange: Bool) -> Phase {
        if hovered { return .expanded }
        guard hasMedia else { return .idle }
        return recentChange ? .titleBanner : .compact
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `swift test --package-path DynamicIslandCore --filter PhaseReducerTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add DynamicIslandCore/Sources/DynamicIslandCore/PhaseReducer.swift DynamicIslandCore/Tests/DynamicIslandCoreTests/PhaseReducerTests.swift
git commit -m "core: PhaseReducer takes recentChange and emits titleBanner"
```

---

## Task 8 — Track-change detection in `NowPlayingService` (TDD)

**Files:**
- Modify: `DynamicIslandCore/Sources/DynamicIslandCore/NowPlayingService.swift`
- Create: `DynamicIslandCore/Tests/DynamicIslandCoreTests/NowPlayingServiceRecentChangeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DynamicIslandCore/Tests/DynamicIslandCoreTests/NowPlayingServiceRecentChangeTests.swift`:

```swift
import XCTest
@testable import DynamicIslandCore

@MainActor
final class NowPlayingServiceRecentChangeTests: XCTestCase {
    private func track(_ title: String) -> Track {
        Track(title: title, artist: "A", album: nil, artwork: nil, duration: 100)
    }

    func test_recentChangeIsFalseInitially() {
        let bridge = FakeBridge()
        let service = NowPlayingService(bridge: bridge)
        XCTAssertFalse(service.recentChange(now: Date(timeIntervalSince1970: 0)))
    }

    func test_recentChangeFlipsTrueOnTitleChange() async {
        let bridge = FakeBridge()
        let now = Date(timeIntervalSince1970: 100)
        let service = NowPlayingService(bridge: bridge, clock: { now })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()

        XCTAssertTrue(service.recentChange(now: now))
    }

    func test_recentChangeStaysTrueWithin4Seconds() async {
        let bridge = FakeBridge()
        let now = Date(timeIntervalSince1970: 100)
        let service = NowPlayingService(bridge: bridge, clock: { now })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()

        XCTAssertTrue(service.recentChange(now: now.addingTimeInterval(3.99)))
    }

    func test_recentChangeFalseAfter4Seconds() async {
        let bridge = FakeBridge()
        let now = Date(timeIntervalSince1970: 100)
        let service = NowPlayingService(bridge: bridge, clock: { now })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()

        XCTAssertFalse(service.recentChange(now: now.addingTimeInterval(4.01)))
    }

    func test_sameTitleDoesNotBumpChange() async {
        let bridge = FakeBridge()
        let firstNow = Date(timeIntervalSince1970: 100)
        var clockNow = firstNow
        let service = NowPlayingService(bridge: bridge, clock: { clockNow })

        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 0))
        await Task.yield()
        clockNow = firstNow.addingTimeInterval(10)
        bridge.emit(NowPlayingSnapshot(track: track("A"), isPlaying: true, elapsed: 5))
        await Task.yield()

        XCTAssertFalse(service.recentChange(now: clockNow))
    }
}
```

- [ ] **Step 2: Run, verify failure**

Run: `swift test --package-path DynamicIslandCore --filter NowPlayingServiceRecentChangeTests`
Expected: compile failure — `NowPlayingService.init(bridge:clock:)` and `recentChange(now:)` undefined.

- [ ] **Step 3: Update `NowPlayingService`**

Overwrite `DynamicIslandCore/Sources/DynamicIslandCore/NowPlayingService.swift`:

```swift
import Foundation
import Combine

@MainActor
public final class NowPlayingService: ObservableObject {
    @Published public private(set) var snapshot: NowPlayingSnapshot = .empty
    @Published public private(set) var lastTrackChangeAt: Date?

    public var hasMedia: Bool { snapshot.track != nil }

    public func recentChange(now: Date, window: TimeInterval = 4.0) -> Bool {
        guard let lastTrackChangeAt else { return false }
        return now.timeIntervalSince(lastTrackChangeAt) < window
    }

    private let bridge: MediaRemoteBridge
    private let clock: @Sendable () -> Date

    public init(
        bridge: MediaRemoteBridge,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.bridge = bridge
        self.clock = clock
        bridge.onChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.ingest(snapshot)
            }
        }
        bridge.start()
    }

    deinit {
        bridge.stop()
    }

    private func ingest(_ next: NowPlayingSnapshot) {
        let prevKey = identityKey(snapshot.track)
        let nextKey = identityKey(next.track)
        if nextKey != nil && nextKey != prevKey {
            lastTrackChangeAt = clock()
        }
        snapshot = next
    }

    private func identityKey(_ track: Track?) -> String? {
        guard let track else { return nil }
        return "\(track.title)\u{1F}\(track.artist)"
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `swift test --package-path DynamicIslandCore --filter NowPlayingServiceRecentChangeTests`
Expected: 5 tests pass.

Also re-run the existing suite to make sure nothing else broke:

Run: `swift test --package-path DynamicIslandCore`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add DynamicIslandCore/Sources/DynamicIslandCore/NowPlayingService.swift DynamicIslandCore/Tests/DynamicIslandCoreTests/NowPlayingServiceRecentChangeTests.swift
git commit -m "core: NowPlayingService tracks recent track change"
```

---

## Task 9 — `EQGlyphView`

**Files:**
- Create: `Dynamic island/Notch/EQGlyphView.swift`

- [ ] **Step 1: Write the view**

Create `Dynamic island/Notch/EQGlyphView.swift`:

```swift
import SwiftUI

struct EQGlyphView: View {
    let isPlaying: Bool
    var barCount: Int = 3
    var spacing: CGFloat = 2
    var barWidth: CGFloat = 2.5
    var color: Color = .white.opacity(0.85)

    @State private var time: TimeInterval = 0
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: height(for: i, in: geo.size.height))
                        .animation(.linear(duration: 1.0 / 30.0), value: time)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            time += 1.0 / 30.0
        }
    }

    private func height(for index: Int, in maxHeight: CGFloat) -> CGFloat {
        guard isPlaying else { return maxHeight * 0.25 }
        let phase = time * 2 * .pi / 0.6 + Double(index) * 2 * .pi / Double(barCount)
        let normalized = (sin(phase) + 1) / 2
        let mapped = 0.25 + normalized * 0.75
        return maxHeight * CGFloat(mapped)
    }
}
```

- [ ] **Step 2: Add to target and build**

Add `EQGlyphView.swift` to the `Dynamic island` target.

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Notch/EQGlyphView.swift" "Dynamic island.xcodeproj/project.pbxproj"
git commit -m "feat(notch): EQGlyphView animated equalizer"
```

---

## Task 10 — `MarqueeText`

**Files:**
- Create: `Dynamic island/Notch/MarqueeText.swift`

- [ ] **Step 1: Write the view**

Create `Dynamic island/Notch/MarqueeText.swift`:

```swift
import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .medium)
    var color: Color = .white
    var speed: Double = 30
    var gap: CGFloat = 32
    var fadeWidth: CGFloat = 16

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if textWidth <= geo.size.width {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .background(WidthReader(width: $textWidth))
                } else {
                    HStack(spacing: gap) {
                        Text(text).fixedSize().background(WidthReader(width: $textWidth))
                        Text(text).fixedSize()
                    }
                    .font(font)
                    .foregroundStyle(color)
                    .offset(x: animate ? -(textWidth + gap) : 0)
                    .animation(
                        .linear(duration: Double(textWidth + gap) / speed)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
                    .onAppear {
                        animate = false
                        DispatchQueue.main.async { animate = true }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: fadeWidth / max(geo.size.width, 1)),
                        .init(color: .black, location: 1 - fadeWidth / max(geo.size.width, 1)),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear { containerWidth = geo.size.width }
        }
    }
}

private struct WidthReader: View {
    @Binding var width: CGFloat
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: WidthKey.self, value: geo.size.width)
        }
        .onPreferenceChange(WidthKey.self) { width = $0 }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
```

- [ ] **Step 2: Add to target, build**

Add to `Dynamic island` target.

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Notch/MarqueeText.swift" "Dynamic island.xcodeproj/project.pbxproj"
git commit -m "feat(notch): MarqueeText scrolling label"
```

---

## Task 11 — `TitleBannerView`

**Files:**
- Create: `Dynamic island/Phases/TitleBannerView.swift`

- [ ] **Step 1: Write the view**

Create `Dynamic island/Phases/TitleBannerView.swift`:

```swift
import SwiftUI
import DynamicIslandCore

struct TitleBannerView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(data: track?.artwork)
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            MarqueeText(text: bannerText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 12)
        .frame(width: 420, height: 40)
    }

    private var bannerText: String {
        guard let track else { return "" }
        if track.artist.isEmpty { return track.title }
        return "\(track.title) — \(track.artist)"
    }
}
```

- [ ] **Step 2: Add to target, build**

Add `TitleBannerView.swift` to the `Dynamic island` target.

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Phases/TitleBannerView.swift" "Dynamic island.xcodeproj/project.pbxproj"
git commit -m "feat(notch): TitleBannerView horizontal banner phase"
```

---

## Task 12 — Wire `.titleBanner` into `NotchView`

**Files:**
- Modify: `Dynamic island/Notch/NotchView.swift`

- [ ] **Step 1: Replace `NotchView` body to handle the new phase**

Overwrite `Dynamic island/Notch/NotchView.swift`:

```swift
import SwiftUI
import DynamicIslandCore

struct NotchView: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let transport: TransportController
    @ObservedObject var hover: HoverTracker
    let notchHotspotWidth: CGFloat
    let notchSize: CGSize
    @Namespace private var artNamespace

    @State private var nowTick: Date = Date()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var phase: Phase {
        PhaseReducer.reduce(
            hovered: hover.isHovered,
            hasMedia: nowPlaying.hasMedia,
            recentChange: nowPlaying.recentChange(now: nowTick)
        )
    }

    private var shapeSize: CGSize {
        switch phase {
        case .idle:
            return CGSize(width: notchSize.width, height: 0.1)
        case .compact:
            return CGSize(width: 200, height: 32)
        case .titleBanner:
            return CGSize(width: 420, height: 40)
        case .expanded:
            return CGSize(width: 380, height: 180)
        }
    }

    private var cornerRadii: (top: CGFloat, bottom: CGFloat) {
        switch phase {
        case .idle:        return (0, 0)
        case .compact:     return (0, 12)
        case .titleBanner: return (0, 20)
        case .expanded:    return (0, 32)
        }
    }

    var body: some View {
        let clipShape = UnevenRoundedRectangle(
            topLeadingRadius: cornerRadii.top,
            bottomLeadingRadius: cornerRadii.bottom,
            bottomTrailingRadius: cornerRadii.bottom,
            topTrailingRadius: cornerRadii.top,
            style: .continuous
        )
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack {
                    NotchBackground(
                        cornerRadius: cornerRadii.bottom,
                        topCornerRadius: cornerRadii.top
                    )
                    content
                        .opacity(phase == .idle ? 0 : 1)
                        .frame(width: shapeSize.width, height: shapeSize.height, alignment: .top)
                        .clipShape(clipShape)
                }
                .frame(width: shapeSize.width, height: shapeSize.height)
                .contentShape(clipShape)
                .onHover { isHovered in
                    hover.setHovered(isHovered)
                }

                Spacer(minLength: 0)
            }

            Color.clear
                .frame(width: notchHotspotWidth, height: notchSize.height + 4)
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered { hover.setHovered(true) }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.all)
        .animation(.interpolatingSpring(stiffness: 220, damping: 22), value: phase)
        .onReceive(tick) { now in nowTick = now }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .compact:
            CompactPhaseView(
                track: nowPlaying.snapshot.track,
                isPlaying: nowPlaying.snapshot.isPlaying,
                artNamespace: artNamespace
            )
            .transition(.opacity)
        case .titleBanner:
            TitleBannerView(
                track: nowPlaying.snapshot.track,
                isPlaying: nowPlaying.snapshot.isPlaying,
                artNamespace: artNamespace
            )
            .transition(.opacity)
        case .expanded:
            ExpandedPhaseView(
                snapshot: nowPlaying.snapshot,
                transport: transport,
                artNamespace: artNamespace
            )
            .transition(.opacity)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Notch/NotchView.swift"
git commit -m "feat(notch): wire titleBanner phase into NotchView"
```

---

## Task 13 — Replace inline `EQBars` with shared `EQGlyphView`

**Files:**
- Modify: `Dynamic island/Phases/CompactPhaseView.swift`

- [ ] **Step 1: Replace the file**

Overwrite `Dynamic island/Phases/CompactPhaseView.swift`:

```swift
import SwiftUI
import DynamicIslandCore

struct CompactPhaseView: View {
    let track: Track?
    let isPlaying: Bool
    let artNamespace: Namespace.ID

    var body: some View {
        HStack {
            ArtworkView(data: track?.artwork)
                .frame(width: 22, height: 22)
                .clipShape(Circle())
                .matchedGeometryEffect(id: "artwork", in: artNamespace)

            Spacer()

            EQGlyphView(isPlaying: isPlaying)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 12)
        .frame(width: 200, height: 32)
    }
}

struct ArtworkView: View {
    let data: Data?

    var body: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(white: 0.15)
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/Phases/CompactPhaseView.swift"
git commit -m "refactor(notch): CompactPhaseView uses shared EQGlyphView"
```

---

## Task 14 — Swap bridge in `AppDelegate`

**Files:**
- Modify: `Dynamic island/App/AppDelegate.swift`

- [ ] **Step 1: Replace bridge construction**

In `Dynamic island/App/AppDelegate.swift` change the line

```swift
let bridge = RealMediaRemoteBridge()
```

to

```swift
let bridge = MediaRemoteAdapterBridge()
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Dynamic island/App/AppDelegate.swift"
git commit -m "feat(app): use MediaRemoteAdapterBridge"
```

---

## Task 15 — Delete the old bridge and AppleScript fallback

**Files:**
- Delete: `Dynamic island/Media/RealMediaRemoteBridge.swift`
- Delete: `Dynamic island/Media/AppleScriptNowPlaying.swift`
- Modify: `Dynamic island.xcodeproj/project.pbxproj`

- [ ] **Step 1: Remove the files from disk**

```bash
git rm "Dynamic island/Media/RealMediaRemoteBridge.swift"
git rm "Dynamic island/Media/AppleScriptNowPlaying.swift"
```

- [ ] **Step 2: Remove file references in Xcode**

In Xcode: Project Navigator → right-click each removed file (red entry) → Delete → "Remove Reference".

- [ ] **Step 3: Drop `NSAppleEventsUsageDescription` from Info.plist key in pbxproj**

In `Dynamic island.xcodeproj/project.pbxproj`, find the two lines (Debug + Release):

```
INFOPLIST_KEY_NSAppleEventsUsageDescription = "Dynamic Island reads now-playing info from Music and Spotify to show track details.";
```

Delete both lines.

- [ ] **Step 4: Build**

Run: `xcodebuild build -project "Dynamic island.xcodeproj" -scheme "Dynamic island"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove RealMediaRemoteBridge + AppleScript fallback"
```

---

## Task 16 — Run all tests

- [ ] **Step 1: Run the full suite**

```bash
swift test --package-path DynamicIslandCore
xcodebuild test -project "Dynamic island.xcodeproj" -scheme "Dynamic island"
```

Expected: every existing and new test passes.

- [ ] **Step 2: If anything fails**

Diagnose the failure, fix it, commit the fix as a separate commit. Do not bundle bug fixes with the migration commits above.

---

## Task 17 — Manual integration check

- [ ] **Step 1: Boot the app**

```bash
xcodebuild -project "Dynamic island.xcodeproj" -scheme "Dynamic island" -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Dynamic\ island.app
```

- [ ] **Step 2: Verify behavior end-to-end**

Walk through the manual checklist (matches the reference recording):

1. With nothing playing, the notch should be the bare physical shape (`.idle`).
2. Open YouTube Music in any browser. Start a track.
   - The notch should enter the compact phase (≈200×32, R=12) within ~1 second.
   - The right edge should show the animated EQ glyph; the left edge a circular artwork dot.
3. Skip to the next track.
   - The notch should expand to the title banner (≈420×40, R=20) and scroll the title.
   - After ~4 seconds, it should collapse back to compact.
4. Pause playback.
   - EQ glyph should freeze at minimum height.
5. Hover over the notch.
   - Drawer (`.expanded`, 380×180) should appear and stay until cursor leaves.
6. Quit the app and relaunch.
   - **No** Apple Events permission prompt should appear for any application.

- [ ] **Step 3: If any step fails**

File the regression as a follow-up bug entry; fix in a separate PR. Do not merge unless steps 1–6 pass.

---

## Self-review notes

- Spec section §Architecture → Tasks 1, 2, 4, 5, 14, 15.
- Spec section §Phase model and visual spec → Tasks 6, 7, 11, 12, 13.
- Spec section §Data flow — track-change trigger → Task 8 + Task 12 (timer wiring).
- Spec section §PhaseReducer truth table → Task 7.
- Spec section §Helper lifecycle → Task 5.
- Spec section §Error handling → Task 5 (`handleLine`, `handleExit`, `defaultProcess` fallback URL).
- Spec section §Distribution → Tasks 1, 2.
- Spec section §Testing → Tasks 3, 5, 7, 8, 16, 17.

No placeholders. No "TBD". All function and type names match across tasks (`AdapterEnvelope`, `AdapterPayload`, `HelperProcess`, `MediaRemoteAdapterBridge`, `EQGlyphView`, `MarqueeText`, `TitleBannerView`, `recentChange(now:)`, `lastTrackChangeAt`, `Phase.titleBanner`).
