# Notch Polish Design

**Date:** 2026-04-29
**Status:** Approved (brainstorming)
**Scope:** Polish pass over the MVP — final shape, dimensions, click handling, and error paths. Builds on `2026-04-29-notch-mvp-design.md`.

## Goal

Tighten visual fidelity, formalize click behaviors, and harden error handling so the app matches the user's reference (Alcove-style Dynamic Island) and gracefully handles real-world failure modes.

## Shape

The island uses SwiftUI's native `UnevenRoundedRectangle(topLeadingRadius:topTrailingRadius:bottomLeadingRadius:bottomTrailingRadius:)` instead of a custom `Shape`. Top corners use a small radius; bottom corners use a larger radius. All corners are convex. The "merge with notch" appearance comes from positioning: the card's top edge sits at panel y=0 (screen top), and the physical notch hardware naturally overlaps the card's center top because both are pure black. The card's wings extend sideways over the menubar.

Per-phase dimensions and radii:

| Phase     | Width | Height | Top radius | Bottom radius |
|-----------|-------|--------|------------|---------------|
| idle      | notch hardware width | 0.1 (effectively invisible) | 0 | 0 |
| compact   | 200   | 30     | 4          | 8             |
| expanded  | 380   | 180    | 8          | 32            |

The legacy `DynamicIslandCore/Sources/DynamicIslandCore/NotchShape.swift` is removed along with its tests (`NotchShapeTests.swift`).

## Animation

Single spring `.spring(response: 0.42, dampingFraction: 0.74)` driven by the `phase` value on the outer container. The shape's frame size animates between phase dimensions; content opacity animates separately (0 in idle, 1 otherwise). Existing scale/opacity transitions inside `content` stay.

## Hover behavior

Unchanged from current implementation. Two hover sources feed `HoverTracker`:

- **Entry hotspot** — `Color.clear` rect sized `notchHotspotWidth × 35` at the top of the panel. `.onHover` sets `true` on enter (no false propagation).
- **Visible card** — `.onHover` on the card's `ZStack` sets `true` on enter and schedules `false` on exit.

`HoverTracker` debounces the `false` transition by 80 ms so the cursor crossing between hotspot and card does not flicker.

A subtle haptic (`NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)`) fires on the false→true transition only.

## Mouse clicks within the island

All five transport controls in the expanded card are clickable:

- **Shuffle** → `TransportController.toggleShuffle` → `MediaCommand.toggleShuffle`
- **Previous** → `TransportController.previous` → `MediaCommand.previous`
- **Play/pause** → `TransportController.playPause` → `MediaCommand.togglePlayPause`
- **Next** → `TransportController.next` → `MediaCommand.next`
- **Output picker** (laptop icon) → opens an `NSMenu` listing available audio outputs

The output picker is implemented in a new `OutputPickerController` that queries CoreAudio (`AudioObjectGetPropertyData` with `kAudioHardwarePropertyDevices` and `kAudioDevicePropertyTransportType`) for output-capable devices. The menu item titles are device names (`kAudioObjectPropertyName`); selecting an item sets the system default output via `kAudioHardwarePropertyDefaultOutputDevice`. If the CoreAudio query fails or returns zero devices, the menu shows a single disabled item "No outputs available".

Clicks outside the card area fall through to the desktop. The `NSHostingView`'s default hit-testing returns `nil` for points where SwiftUI rendered nothing (`Color.clear`, transparent regions outside the shape's actual frame), so the panel does not absorb clicks in its empty edges.

## Error handling

The bridge already swallows `dlopen` and `dlsym` failures silently. This pass adds:

- **`MRMediaRemoteSendCommand` return value check.** The C function returns `Bool` indicating whether the command was accepted. `TransportController` was discarding it; now the result is logged via `NSLog` on `false` so failures are observable in Console without surfacing UI noise. Behavior is unchanged from the user's perspective — failed commands silently no-op.
- **No-active-client edge case.** When the user clicks a transport button and no media application is registered with MediaRemote, the send returns `false`. No alert, no UI change. Matches macOS norms (system menu volume controls behave the same).
- **CoreAudio query failure.** `OutputPickerController` returns an empty list; the menu shows "No outputs available" disabled.
- **Notch hardware missing on launch.** Existing behavior preserved: alert + `NSApp.terminate(nil)`.

No new error types or alerts are introduced. All recoverable failures degrade silently with one `NSLog` line for diagnostics.

## Edge effect

Unchanged from current implementation. The shape carries a single drop shadow:

```swift
.shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
```

No inner stroke, no glow, no glass material — flat black with a soft outer shadow. This matches reference Image 22.

The white-opacity 0.18 hairline stroke around the shape introduced in an earlier pass remains, providing a faint rim against bright wallpapers without dominating the silhouette.

## File changes

| File | Change |
|------|--------|
| `DynamicIslandCore/Sources/DynamicIslandCore/NotchShape.swift` | DELETE |
| `DynamicIslandCore/Tests/DynamicIslandCoreTests/NotchShapeTests.swift` | DELETE |
| `Dynamic island/Notch/NotchBackground.swift` | Replace `NotchShape` with `UnevenRoundedRectangle` |
| `Dynamic island/Notch/NotchView.swift` | Update phase dimensions and per-corner radii to spec table |
| `Dynamic island/Phases/ExpandedPhaseView.swift` | Wire output-picker button to `OutputPickerController.present(at:)` |
| `Dynamic island/Media/OutputPickerController.swift` | NEW — CoreAudio device list + selection + `NSMenu` builder |
| `DynamicIslandCore/Sources/DynamicIslandCore/TransportController.swift` | Capture `MRMediaRemoteSendCommand` return value; log on false |
| `DynamicIslandCore/Sources/DynamicIslandCore/MediaRemoteBridge.swift` | Change protocol `send(_:)` to return `@discardableResult Bool` |
| `Dynamic island/Media/RealMediaRemoteBridge.swift` | Return the actual `MRMediaRemoteSendCommand` Bool result from `send(_:)` |
| `DynamicIslandCore/Tests/DynamicIslandCoreTests/NowPlayingServiceTests.swift` | Update `FakeBridge.send` to return `Bool` (always `true`) |

## Out of scope

- Notifications, additional Live Activities (timers, AirDrop, etc.), HUD override, widgets, gestures, settings UI, paywall — all still deferred to later specs.
- Visual blur material (`NSVisualEffectView`) — user picked flat shadow only.
- Per-app icon detection or smart "now playing app" indication beyond what MediaRemote returns.

## Risks

- **CoreAudio query latency.** First call after a sleep/wake or device-list change can take 50-100 ms. Acceptable since the menu opens on user click — synchronous fetch is fine.
- **Output device selection requires `kAudioHardwarePropertyDefaultOutputDevice` write.** No special entitlement needed in non-sandboxed apps; sandbox is already disabled.
- **`UnevenRoundedRectangle` requires macOS 13+.** Project targets macOS 14, so safe.
