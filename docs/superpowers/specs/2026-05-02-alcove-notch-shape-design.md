# Alcove Notch Shape — Design

**Date:** 2026-05-02
**Branch:** `feat/notch-mvp`
**References:** four user-supplied screenshots showing idle / compact / mid-expanded / expanded phases of the Alcove app.

## Goal

Replace the current flat-top pill silhouette with the canonical Apple Dynamic Island silhouette: a rounded-bottom pill whose top shoulders extend horizontally past the side edges and curve down into the side via concave (inverse) arcs, so the pill appears to flow into the menu bar above it.

## Non-goals

- Changing the data pipeline. The `MediaRemoteAdapterBridge` and `NowPlayingService` stay as-is.
- Changing phase trigger logic. `PhaseReducer` stays as-is.

## Architecture

A single custom `Shape` (`NotchShape`) draws the full silhouette. The shape is taller than its declared frame by `topInvertedRadius` because the path extends above `y = 0` to form the shoulders. The view that hosts it pads its top by `-topInvertedRadius` so the shoulders align with the menu bar bottom.

```
y = -tR  ┌─────────────────────────┐  shoulders flush with menu bar bottom
         ╲                         ╱
          ╲                       ╱  inverse (concave) arcs, radius tR
y =  0     │   pill body         │   declared frame top
           │                     │
y = H-bR   ╰─                   ─╯   convex bottom corners, radius bR
y =  H      ─────────────────────    bottom edge
```

The `tR` matches the physical notch's own bottom corner radius, so the shoulder cutouts visually continue the menu bar's hardware curve.

## Components

### New

| File | Role |
|---|---|
| `Dynamic island/Notch/NotchShape.swift` | `Shape` that draws the silhouette and exposes animatable `width`, `height`, `bottomRadius`, `topInvertedRadius`. |
| `DynamicIslandCore/Tests/DynamicIslandCoreTests/NotchShapePathTests.swift` | XCTest cases that verify key path vertices. (Cross-target test — `NotchShape` lives in the app target, so we add a thin mirror in the package, or we keep tests inside the app's test target. Plan task 5 picks the simpler one.) |

### Changed

| File | Change |
|---|---|
| `Dynamic island/Notch/NotchBackground.swift` | Render `NotchShape` instead of `UnevenRoundedRectangle`. Take a `geometry` value with `(width, height, topInvertedRadius, bottomRadius)`. |
| `Dynamic island/Notch/NotchView.swift` | Replace `UnevenRoundedRectangle` clip with `NotchShape`. Add per-phase `geometry` table that uses the alcove dimensions. Wrap shape in `ZStack` with `.padding(.top, -topInvertedRadius)` so shoulders sit at menu bar bottom. |
| `Dynamic island/Phases/CompactPhaseView.swift` | Resize to match new compact dimensions. Center content vertically so it sits within the menu-bar-height pill. |
| `Dynamic island/Phases/TitleBannerView.swift` | Resize to 580 × 88. Layout: artwork (left, ⌀40 circle), MarqueeText (middle), EQ glyph (right, ⌀22). Top portion of the view aligns with menu-bar height, bottom portion drops below. |
| `Dynamic island/Phases/ExpandedPhaseView.swift` | Resize to 770 × 280. Bigger artwork (⌀88), bigger title/artist text, scrubber + transport row laid out for the wider panel. |
| `Dynamic island/Notch/NotchWindowController.swift` | `panelWidth = 880`, `panelHeight = 320` so even the largest expanded phase + shoulder padding fits. |

## Phase geometry

| Phase | W | H | bottomR | topInvR | Notes |
|---|---|---|---|---|---|
| idle | `notchSize.width` | 0.1 | 0 | 0 | Effectively invisible. |
| compact | `notchSize.width + 80` | `notchSize.height` | 0 | 12 | Pill height = physical notch height. No curl below the notch. Bottom is flat. |
| titleBanner | 580 | 88 | 24 | 12 | Pill drops 50pt below physical notch bottom. |
| expanded | 770 | 280 | 32 | 12 | Drawer phase. |

`topInvR` is constant 12pt across the three visible phases — it matches the physical notch's bottom corner radius so the silhouette appears to continue the hardware curve.

## NotchShape path math

The shape's logical frame is `(0, 0, W, H)`. The path extends from `y = -tR` to `y = H`. Caller is responsible for the `-tR` top offset.

```
let tR = topInvertedRadius
let bR = min(bottomRadius, min(W, H) / 2)

// Trace clockwise starting at upper-left shoulder corner.

// 1) Outer top edge.
move(to: (-tR, -tR))
addLine(to: (W + tR, -tR))

// 2) Inverse arc on the right shoulder.
//    Quarter circle, center (W + tR, 0), radius tR.
//    Sweeps from angle 180° (which is (W, 0) — left of center) wait re-derive.
//
//    SwiftUI angles: 0° = +x, 90° = +y (down), 180° = -x, 270° = -y (up).
//    Center C = (W + tR, 0). Radius tR.
//    Angle 180°  → (W + tR + tR·cos180°, 0 + tR·sin180°) = (W, 0)            ← we want to end here
//    Angle 270°  → (W + tR, -tR)                                              ← we are coming from here
//    So arc goes 270° → 180° going clockwise in screen coords (which is CCW
//    in math because y is flipped). SwiftUI's `clockwise` parameter means
//    visually clockwise in screen coords.
addArc(center: (W + tR, 0), radius: tR,
       startAngle: 270°, endAngle: 180°, clockwise: false)

// 3) Right side of pill body.
addLine(to: (W, H - bR))

// 4) Bottom-right convex.
addArc(center: (W - bR, H - bR), radius: bR,
       startAngle: 0°, endAngle: 90°, clockwise: false)

// 5) Bottom edge.
addLine(to: (bR, H))

// 6) Bottom-left convex.
addArc(center: (bR, H - bR), radius: bR,
       startAngle: 90°, endAngle: 180°, clockwise: false)

// 7) Left side of pill body.
addLine(to: (0, 0))

// 8) Inverse arc on the left shoulder.
//    Center (-tR, 0), radius tR.
//    Angle 0°    → (0, 0)                                                       ← coming from here
//    Angle 90°   → (-tR, tR) — wait that's below. We want (-tR, -tR).
//    Angle 270°  → (-tR, -tR)                                                   ← end here
//    Arc 0° → 270° clockwise in screen coords means going through 315°
//    which is up-and-right, which is wrong. Going CCW visual (clockwise: false)
//    from 0° goes through 45°, 90° (down) — also wrong.
//    Correct: arc from 0° → 270° going CCW visually = going through 315°
//    (which is up-and-right of center). Wait: 315° in SwiftUI is (cos315°,
//    sin315°) = (0.707, -0.707) so center + r·(0.707, -0.707) = (-tR + 0.707tR,
//    0 - 0.707tR) = (-0.293tR, -0.707tR). That's UP-AND-RIGHT of center,
//    INSIDE the silhouette (between the two shoulders). 
//    Going visually CCW from 0° to 270° passes through 315° (yes that's
//    the short way visually).
//    SwiftUI clockwise parameter: `false` means CCW in screen coords.
//    Note: the "clockwise" docs are widely considered confusing. We'll
//    pick the value that makes the test pass.
addArc(center: (-tR, 0), radius: tR,
       startAngle: 0°, endAngle: 270°, clockwise: true)

closeSubpath()
```

The shape struct:

```swift
struct NotchShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var bottomRadius: CGFloat
    var topInvertedRadius: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            .init(.init(width, height), .init(bottomRadius, topInvertedRadius))
        }
        set {
            width = newValue.first.first
            height = newValue.first.second
            bottomRadius = newValue.second.first
            topInvertedRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path { /* per math above */ }
}
```

The `path(in:)` ignores `rect` and uses its own `(width, height)` — this lets SwiftUI animate the shape's size by interpolating the property bag, while the wrapping frame stays anchored.

## Container layout in `NotchView`

```swift
let geom = phase.geometry  // (W, H, bottomR, topR)
ZStack(alignment: .top) {
    NotchShape(width: geom.W, height: geom.H,
               bottomRadius: geom.bottomR, topInvertedRadius: geom.topR)
        .fill(.black)
        .background {
            NotchShape(...)
                .fill(.ultraThinMaterial)
                .blur(radius: 10)
                .padding(-10)
        }
        .frame(width: geom.W, height: geom.H)
        .padding(.top, -geom.topR) // shoulder zone above frame top

    content
        .frame(width: geom.W, height: geom.H)
        .clipShape(NotchShape(width: geom.W, height: geom.H,
                              bottomRadius: geom.bottomR,
                              topInvertedRadius: 0)) // content stays inside body, no shoulders
}
.animation(.smooth(duration: 0.5, extraBounce: 0.18), value: phase)
```

Two `NotchShape` instances per render: one with shoulders (visual), one without (content clip).

## Hover semantics

The hit-test region must include the shoulders so the cursor entering the menu-bar curve still triggers expansion. Apply `contentShape(NotchShape(... topR ...))` to the hover-detecting view.

## Testing

- `NotchShapePathTests` (in `DynamicIslandCoreTests` mirror, see plan):
  - Bounding box of path = `CGRect(x: -tR, y: -tR, width: W + 2tR, height: H + tR)`.
  - Path contains key interior points: `(W/2, 1)` (just inside top edge), `(W/2, H - 1)`.
  - Path does NOT contain `(W + 0.5, -tR + 0.5)` (just outside right shoulder corner) — concave bite is real.
- `PhaseReducerTests` unchanged.
- Manual: launch app, play music. Observe each phase visually matches reference screenshots.

## Migration

Single PR. `NotchShape.swift` is new. The other touched files are tweaks to existing code (sizes, clip shapes). No data-pipeline changes.

## Risks

- SwiftUI `Shape.animatableData` — animating four scalars at once can stutter at low frame rates. Acceptable: macOS hosts run at 60-120 Hz with a 0.5s spring.
- The `clockwise:` parameter on `Path.addArc` is famously misnamed in SwiftUI. The plan task that adds `NotchShape` includes a quick visual smoke test before committing — render the shape full-window in a debug preview, eyeball the silhouette, adjust if the arcs face the wrong way.
