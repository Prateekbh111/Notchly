# Source-Agnostic Now Playing — Design

**Date:** 2026-05-01
**Branch:** `feat/notch-mvp` (continues notch MVP work)
**Reference:** `refrence.mov` (screen recording demonstrating target behavior)

## Goal

Replace per-app AppleScript fallback (which prompts macOS Apple-Events consent for every supported source) with a single source-agnostic now-playing pipeline. Match the motion/shape behavior shown in the reference recording exactly.

Outcome:

1. Zero per-app permission prompts on first launch.
2. Now-playing data captured for any audio source that publishes to system MediaRemote (YouTube Music in any browser, Spotify, Music.app, AirPlay receivers, Bluetooth-paired phones, etc.).
3. Track-change auto-expands the notch to a horizontal title banner that scrolls the track name, then collapses to a compact pill with an animated EQ glyph.

## Non-goals

- Audio capture / fingerprinting (rejected — adds consent surface, latency).
- Browser extensions (rejected — per-browser distribution overhead).
- Re-design of the hover-drawer expanded phase (kept as-is).

## Architecture

```
[macOS MediaRemote] ──events──> [helper binary] ──NDJSON via stdout pipe──>
    [MediaRemoteAdapterBridge] ──NowPlayingSnapshot──>
        [NowPlayingService] ──@Published──>
            [NotchView ── PhaseReducer]
```

Helper = `mediaremote-adapter` from `https://github.com/ungive/mediaremote-adapter` (MIT). Compiled binary committed under `Vendor/mediaremote-adapter/` and copied into the app bundle's `Contents/Resources/` at build time.

The helper registers as a MediaRemote client via Apple's private `MRRemoteControlAgent` interface. macOS treats it as a peer of Music.app / Spotify, so it receives source-agnostic now-playing notifications without per-app TCC prompts.

## Components

### New

| File | Role |
|---|---|
| `Dynamic island/Media/MediaRemoteAdapterBridge.swift` | Implements `MediaRemoteBridge`. Spawns helper via `Process`, parses NDJSON, maps to `NowPlayingSnapshot`, calls `onChange`. Handles helper crash with capped relaunch. |
| `Dynamic island/Media/AdapterPayload.swift` | `Codable` mirror of helper JSON envelope. |
| `Dynamic island/Notch/MarqueeText.swift` | Horizontally scrolling text view, used inside `TitleBannerView`. Pauses when title fits. |
| `Dynamic island/Notch/EQGlyphView.swift` | 3-bar animated equalizer. Heights driven by per-bar phase-shifted sin waves. Pauses when `!isPlaying`. |
| `Dynamic island/Notch/TitleBannerView.swift` | The new horizontal-banner phase view: artwork dot · marquee title · EQ glyph. |
| `Vendor/mediaremote-adapter/` | Pre-built helper binary + `LICENSE`. |

### Changed

| File | Change |
|---|---|
| `DynamicIslandCore/.../Phase.swift` | Add case `titleBanner`. Order: `idle`, `compact`, `titleBanner`, `expanded`. |
| `DynamicIslandCore/.../PhaseReducer.swift` | New signature: `reduce(hovered: Bool, hasMedia: Bool, recentChange: Bool, now: Date) -> Phase`. |
| `DynamicIslandCore/.../NowPlayingService.swift` | Track `lastTrackChangeAt: Date?`. Bump it whenever `(title, artist)` tuple changes. Expose `recentChange(now:) -> Bool` (true within 4.0s). |
| `Dynamic island/Notch/NotchView.swift` | Read `recentChange`, pass to reducer. Add `titleBanner` case in `shapeSize`, `cornerRadii`, `content` switch. |
| `Dynamic island/Notch/CompactPhaseView.swift` | Use `EQGlyphView` on the right edge instead of any prior right-side affordance. Artwork = small circular dot on left. |
| `Dynamic island/MediaRemoteBridge` wiring | Swap concrete type from `RealMediaRemoteBridge` to `MediaRemoteAdapterBridge`. |
| `Info.plist` (via project.pbxproj) | Drop `NSAppleEventsUsageDescription`. |

### Deleted

| File | Reason |
|---|---|
| `Dynamic island/Media/RealMediaRemoteBridge.swift` | Private-symbol path is gated on macOS 15.4+; AppleScript fallback path is what the user is rejecting. |
| `Dynamic island/Media/AppleScriptNowPlaying.swift` | No longer reachable. |

## Phase model and visual spec

| Phase | Width × Height | Bottom corner radius | Top corner radius | Content |
|---|---|---|---|---|
| `idle` | `notchSize.width × 0.1` | 0 | 0 | empty |
| `compact` | `200 × 32` | 12 | 0 | artwork dot (left, ⌀22), EQ glyph (right, 14×14) |
| `titleBanner` | `420 × 40` | 20 | 0 | artwork dot (left, ⌀26), scrolling title (center), EQ glyph (right, 16×16) |
| `expanded` | `380 × 180` | 32 | 0 | unchanged from current design (hover drawer) |

Width/height/corner-radius interpolation: `interpolatingSpring(stiffness: 220, damping: 22)`, applied to `phase` value via `.animation(_:value:)`.

Title fade-in/out within `titleBanner`: `.opacity` transition, `0.18s` ease-out.

`EQGlyphView`: three rounded-rect bars (width 2.5, spacing 2, max height = view height), heights driven by `sin(time * 2π / 0.6 + i * 2π/3)` mapped to `[0.25, 1.0]`. Bar fill `Color.white.opacity(0.85)`. When `!isPlaying`, all bars hold at 0.25 height.

`MarqueeText`: measures intrinsic text width vs container width. If text fits, render static. If not, render text + 32-px gap + duplicate-text and translate horizontally with a linear `Animation.linear(duration: textWidth / 30).repeatForever(autoreverses: false)` (≈30 pt/s). Mask edges with a 16-pt linear-gradient fade so text appears to slide under the rounded corners.

## Data flow — track-change trigger

1. Helper emits NDJSON event `{type: "playing", payload: {title, artist, album, artworkData (base64), duration, elapsedTime, playbackRate, bundleIdentifier}}` whenever MediaRemote notifies.
2. `MediaRemoteAdapterBridge` decodes, builds `NowPlayingSnapshot`, calls `onChange` on main queue.
3. `NowPlayingService` receives snapshot. If `(snapshot.track?.title, snapshot.track?.artist)` differs from prior, set `lastTrackChangeAt = Date()`. Otherwise leave it untouched.
4. `NowPlayingService` runs a `Timer.publish(every: 0.5)` while `lastTrackChangeAt != nil` and `< 4s` ago, so the SwiftUI view re-evaluates `recentChange` and naturally collapses when the window expires.
5. `PhaseReducer` returns `.titleBanner` when `hasMedia && recentChange && !hovered`. Hover still wins (drawer takes priority).

## PhaseReducer truth table

| hovered | hasMedia | recentChange | Phase |
|---|---|---|---|
| F | F | F | `.idle` |
| F | F | T | `.idle` (defensive — no track means no banner) |
| F | T | F | `.compact` |
| F | T | T | `.titleBanner` |
| T | F | F | `.expanded` |
| T | F | T | `.expanded` |
| T | T | F | `.expanded` |
| T | T | T | `.expanded` |

## Helper lifecycle

- `MediaRemoteAdapterBridge.start()`: locate helper at `Bundle.main.url(forResource: "mediaremote-adapter", withExtension: nil, subdirectory: nil)`. `Process.launch()` it with stdout piped.
- Set `terminationHandler` to schedule `relaunch()` after a 1s delay if the helper exits while the bridge is still active.
- Crash-loop guard: keep a circular buffer of last 3 launch timestamps. If 3 launches fall within 10s, stop relaunching and emit `NowPlayingSnapshot.empty` so the notch returns to idle. Surface a single `NSLog` line with the helper exit status.
- `stop()`: `process.terminate()`, drain pipes, nil out callbacks.

## Error handling

| Failure | Behavior |
|---|---|
| Helper binary missing from bundle | `NSLog` on startup, publish `.empty`, do not crash. |
| Helper exits cleanly (status 0) | Treat as user log-out / sleep wake; relaunch with normal backoff. |
| Helper exits abnormally | Relaunch under crash-loop guard. |
| NDJSON line fails to decode | Drop the line, `NSLog` once per session, continue. |
| Artwork base64 decode fails | Use `nil` artwork, keep title/artist. |
| MediaRemote silent for >5min while playing flag is true | No special handling — the helper is the source of truth. |

## Distribution

- `Vendor/mediaremote-adapter/mediaremote-adapter` (universal binary, codesigned ad-hoc by upstream).
- `Vendor/mediaremote-adapter/LICENSE` (MIT).
- Xcode "Copy Files" build phase, destination `Resources`, copies the binary into the bundle. The phase runs after `Compile Sources`.
- Re-codesigning happens automatically as part of the host app's signing — no manual entitlements needed.
- The helper itself does not need entitlements; the private MediaRemote symbols it uses are read at runtime via `dlopen`/`dlsym`.

## Testing

### Unit

- `PhaseReducerTests`: replace existing 4-row table with the 8-row table above.
- `NowPlayingServiceTests`:
  - `recentChange` returns true within 4s of a title change.
  - `recentChange` flips back to false at exactly 4.0s.
  - Same-track snapshots (no title/artist change) do not bump `lastTrackChangeAt`.
- `MediaRemoteAdapterBridgeTests`:
  - Inject a `Process`-like protocol. Feed canned NDJSON byte streams.
  - Assert one `onChange` per envelope.
  - Assert relaunch fires after termination and is suppressed after 3 crashes/10s.
- `MarqueeText` snapshot test: short text static, long text animates.

### Integration / manual

- Launch app with no music playing → notch in `.idle`.
- Start YouTube Music in browser → notch enters `.compact` within ~500ms.
- Skip to next track → notch enters `.titleBanner`, title scrolls, collapses to `.compact` after 4s.
- Pause playback → EQ bars freeze; `isPlaying` propagates.
- Switch source mid-playback (browser → Spotify) → no extra prompts; notch updates.
- Quit and relaunch app → no permission prompts at all.

## Migration / rollout

Single PR. No feature flag needed — the AppleScript path is being replaced wholesale, not toggled. Branch `feat/notch-mvp` already has the polish work; this stacks on top.

## Open risks

- The MediaRemote private interfaces could break in a future macOS point release. Mitigation: helper failure degrades gracefully to `.idle`. Replace upstream binary on breakage.
- AirPlay-only sources (e.g., HomePod controlling iPhone playback) emit limited metadata. Acceptable; we render what we get.
- Some Electron apps don't publish to MediaRemote at all (e.g., older Slack huddles, some games). Out of scope.
