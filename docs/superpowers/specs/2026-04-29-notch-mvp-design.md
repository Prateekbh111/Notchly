# Dynamic Island for Mac — Notch MVP Design

**Date:** 2026-04-29
**Status:** Approved (brainstorming)
**Scope:** MVP — notch shell + music Live Activity

## Goal

Bring iPhone Dynamic Island to MacBooks with notches. The physical notch is treated as a hardware anchor; software draws around and below it, morphing fluidly between phases as media state changes. MVP delivers the notch shell and one Live Activity (music). All other features (notifications, HUD override, AirDrop drag, widgets, gestures, settings, paywall) are deferred to subsequent specs.

## Hardware Scope

Notch-equipped Macs only:

- MacBook Pro 14"/16" (2021+, M1 Pro/Max, M2/M3/M4 Pro/Max)
- MacBook Air 13"/15" (M2/M3)

On any other Mac the app refuses to launch and shows an alert. Notch is detected via `NSScreen.safeAreaInsets.top > 0` on the built-in display, with `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` confirming the notch geometry. External displays are ignored — the app only renders on the built-in screen.

## Visual Reference

Three phases, anchored to the physical notch:

- **Idle** — no media playing, no hover. Notch shape only; nothing rendered by the app.
- **Compact** — media playing, no hover. Notch grows into a horizontal pill: small album-art tile on the left, animated EQ bars on the right, top edge flush with the notch.
- **Expanded** — hover OR click on notch. A rounded card hangs below the notch: album art (square, top-left), title and artist (top-right), EQ icon (right edge), scrubber with elapsed and remaining time, transport row (shuffle, prev, play/pause, next, output picker). When nothing is playing, the same expanded card shows a "Not Playing" state.

Transitions between phases use a single SwiftUI spring animation with `matchedGeometryEffect` so the album art, pill outline, and surrounding shape morph as one continuous element.

## Architecture

```
Dynamic_islandApp (LSUIElement, NSApplicationDelegateAdaptor)
└── AppDelegate
    ├── NotchWindowController       // NSPanel mgmt, screen anchor, hover tracking
    │   └── NotchView (SwiftUI)     // root, observes services, drives morph
    │       ├── NotchShape          // custom Shape — flat top, rounded bottom
    │       ├── IdlePhaseView       // empty
    │       ├── CompactPhaseView    // mini artwork + EQ
    │       └── ExpandedPhaseView   // full player card
    ├── NowPlayingService           // MediaRemote bridge → @Published state
    ├── TransportController         // play/pause/next/prev/shuffle dispatch
    └── HoverTracker                // NSTrackingArea on notch hotspot
```

The app launches as `LSUIElement` (no Dock icon, no menu bar). All UI lives inside the notch panel.

## Components

| Unit | Purpose | Inputs | Outputs |
|------|---------|--------|---------|
| `NotchWindowController` | Build & anchor `NSPanel`, install tracking area, rebuild on screen change | `NSScreen` | sized panel, hover signal |
| `NotchView` | Render current phase, drive morph | `Phase`, `Track?` | SwiftUI tree |
| `NotchShape` | `Shape` — top flat (notch cutout), rounded bottom expansion | `width`, `height`, `cornerRadius` | `Path` |
| `Phase` | Enum: `idle`, `compact`, `expanded` | — | — |
| `PhaseReducer` | Pure function: `(hovered: Bool, hasMedia: Bool) -> Phase` | bool×bool | `Phase` |
| `HoverTracker` | `NSTrackingArea` over notch hotspot rect | mouse events | `@Published isHovered` |
| `NowPlayingService` | Observe MediaRemote, expose track state | system | `@Published track: Track?`, `isPlaying`, `elapsed`, `duration` |
| `MediaRemoteBridge` | `dlopen` `MediaRemote.framework`, call `MRMediaRemoteGetNowPlayingInfo`, register for `kMRMediaRemoteNowPlayingInfoDidChangeNotification` | — | callbacks on main actor |
| `TransportController` | Send commands via `MRMediaRemoteSendCommand` | `Command` enum | system effect |
| `Track` | Value type — title, artist, album, artwork, duration | — | — |

Each component has one purpose. `MediaRemoteBridge` is the only file that knows about the private framework — everything above it consumes a Swift-friendly API and can be mocked.

## State Machine

```
                   hasMedia=false      hasMedia=true
hover=false        idle                compact
hover=true         expanded            expanded
```

Hover always wins (so users can peek "Not Playing" by hovering the notch). All transitions use `withAnimation(.spring(response: 0.35, dampingFraction: 0.78))`.

## Window / Panel Strategy

`NSPanel` configured for an always-on-top notch overlay:

- Style mask: `.borderless` + `.nonactivatingPanel`
- Level: `.statusBar + 1` (renders above menubar)
- `collectionBehavior`: `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
- `isMovable = false`, `hasShadow = false`, `backgroundColor = .clear`, `isOpaque = false`
- Accepts mouse events but does not steal focus

**Sizing:** the panel is always sized to the maximum bounds the expanded phase requires (≈360 × 180 pt). The morphing shape is drawn *inside* the panel, so panel frame never changes during animation — only the SwiftUI shape does. This avoids `NSPanel` resize jitter.

**Anchoring:** origin = `screen.frame.maxY - panelHeight` (top edge), X centered on notch midpoint (computed from `auxiliaryTopLeftArea.maxX` and `auxiliaryTopRightArea.minX`).

**Click-through:** `NotchPanel` overrides hit-testing — returns the content view only when the cursor is inside the current phase's shape `Path`. Outside the shape, hit-test returns `nil` so clicks fall through to the desktop. This keeps the notch hotspot active in idle without trapping random clicks across the top of the screen.

**Screen reconfiguration:** `NSApplication.didChangeScreenParametersNotification` triggers rebuild of panel frame and tracking area.

## Data Flow

**Now Playing → UI:**

```
MediaRemote CFNotification
    → MediaRemoteBridge (callback on main actor)
    → NowPlayingService.update(...)
    → @Published track / isPlaying / elapsed
    → NotchView body re-renders
    → PhaseReducer recomputes Phase
    → withAnimation morphs shape + content
```

**Hover → UI:**

```
NSTrackingArea mouseEntered/Exited
    → HoverTracker.isHovered = true/false
    → NotchView observes → PhaseReducer → Phase
```

**Transport → system:**

```
SwiftUI Button tap
    → TransportController.send(.playPause | .next | .previous | .shuffle)
    → MRMediaRemoteSendCommand(commandID, nil)
    → system updates player → MediaRemote re-fires → UI updates
```

## Error Handling

- **MediaRemote `dlopen` fails:** `MediaRemoteBridge` returns `.unavailable`. `NowPlayingService` reports no media. App stays in idle. One log line; no user-facing alert (private framework breakage is rare and unrecoverable from user side).
- **Non-notch Mac:** `NotchWindowController` detects no notch, presents alert ("Dynamic Island requires a MacBook with a notch"), quits.
- **Multi-display:** anchor only to the built-in display. External monitors are ignored.
- **Screen reconfigure:** rebuild panel frame and tracking area on `didChangeScreenParametersNotification`.
- **Artwork decode failure:** fall back to a music-note glyph (mirrors the "Not Playing" reference visual).
- **Track metadata partial (title only, no artwork, etc.):** render whatever fields are present; missing fields collapse silently.

## Testing

- **Unit — `PhaseReducer`:** pure function, table-driven tests covering all four `(hovered, hasMedia)` combinations.
- **Unit — `NotchShape`:** snapshot tests of `path(in:)` for each phase's expected size.
- **Unit — `NowPlayingService`:** inject a `MediaRemoteBridge` protocol mock; assert published state matches simulated callbacks.
- **Unit — `TransportController`:** mock command sender; assert correct command IDs.
- **Integration (manual):** matrix on dev Mac:
  1. No media → idle
  2. Play in Music.app → compact within ~500ms
  3. Hover compact → expanded
  4. Leave hover → compact
  5. Pause → play icon swap, EQ bars stop animating
  6. Next/prev → track metadata updates
  7. Quit Music → idle within ~1s
  8. Switch player (Music → Spotify) → metadata updates correctly
  9. Plug/unplug external display → panel stays on built-in
  10. Switch Spaces / enter fullscreen → panel still visible

UI XCTest is not used — private framework dependency and `.statusBar + 1` window level make automated UI tests brittle for marginal value.

## File Layout

```
Dynamic island/
├── Dynamic_islandApp.swift              # @main, LSUIElement, AppDelegate adapter
├── App/
│   └── AppDelegate.swift                # service wiring, lifecycle
├── Notch/
│   ├── NotchWindowController.swift
│   ├── NotchPanel.swift                 # NSPanel subclass with hit-test override
│   ├── NotchView.swift
│   ├── NotchShape.swift
│   ├── Phase.swift
│   ├── PhaseReducer.swift
│   └── HoverTracker.swift
├── Phases/
│   ├── IdlePhaseView.swift
│   ├── CompactPhaseView.swift
│   └── ExpandedPhaseView.swift
└── Media/
    ├── Track.swift
    ├── NowPlayingService.swift
    ├── MediaRemoteBridge.swift
    └── TransportController.swift
```

## Out of Scope (MVP)

Deferred to subsequent specs:

- Notifications bridge
- Additional Live Activities (timers, AirDrop, charging, screen recording, focus)
- Volume / brightness HUD override
- Trackpad gestures (swipe-on-notch, drag-to-notch)
- Desktop / menubar widgets
- Settings UI
- Themes / customization
- Licensing / paywall

## Risks & Open Questions

- **MediaRemote private API:** Apple has not removed it through current macOS releases, but it remains undocumented. If a future macOS removes or sandboxes it, the app degrades to idle gracefully. No App Store distribution path — direct download only.
- **Notch overlay above menubar:** `.statusBar + 1` works in current macOS; if Apple tightens window-level rules, fall back to a status-bar-level panel and accept rendering below menubar text (still visible because the menubar around the notch is empty).
- **Hover hotspot size:** the tracking area must be slightly larger than the notch itself so the user can trigger expansion without pixel-perfect aim. Tunable; default to notch width + 40pt horizontal, 20pt vertical below notch.
