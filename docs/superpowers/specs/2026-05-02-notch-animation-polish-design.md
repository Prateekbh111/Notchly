# Notch Animation Polish — Design

**Date:** 2026-05-02
**Branch:** `feat/notch-mvp`
**References:** `refrence.mov`, `ref2.mp4` (alcove), four user-supplied screenshots.

## Goal

Match the alcove "drop curtain" expand animation: shape morphs first, content fades in mid-morph, subtle blur halo around the pill.

## Non-goals

- Changing the silhouette (stays as-is: rounded-bottom pill with constant tR=12 inverse shoulders).
- Changing per-phase dimensions.
- Changing the data pipeline.

## Animation tracks

Three tracks animate concurrently when phase changes:

| Track | Driver | Curve | Duration | Delay |
|---|---|---|---|---|
| Shape (W/H/bR) | `Phase` value change | `.smooth(extraBounce: 0.18)` | 0.45s | 0 |
| Content opacity | View transition | `.easeOut` | 0.25s | 0.1s |
| Halo / shadow | static, non-animated | — | — | — |

The content's 0.1s delay creates the "shape morphs first then content reveals" feel.

## NotchBackground

Add a black drop shadow to the existing fill:

```swift
shape
    .fill(.black)
    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    .background {
        shape
            .fill(.ultraThinMaterial)
            .blur(radius: 10)
            .padding(-10)
    }
```

The shadow applies to the SwiftUI render of the shape, casting a soft halo below and around the pill — picks up the bottom-edge glow visible during alcove's drop-down.

## Content transition

Replace existing `.transition(.opacity)` on each phase view with:

```swift
.transition(
    .opacity.animation(.easeOut(duration: 0.25).delay(0.1))
)
```

If the `.delay()` chained on transition animation does not survive SwiftUI's transition machinery on macOS 26.4, fallback: drive the content opacity from a `@State` mirror that updates `0.1s` after the phase change via `.onChange(of: phase) { _ in withAnimation(...) { ... } }`.

## NotchView animation modifier

Currently:

```swift
.animation(.smooth(duration: 0.42, extraBounce: 0.22), value: phase)
```

Update to:

```swift
.animation(.smooth(duration: 0.45, extraBounce: 0.18), value: phase)
```

This now animates everything that changes when `phase` changes — including the `.padding(.top, ...)`, frame size, NotchShape's animatableData, etc.

The content's transition has its own animation override, so the spring does not apply to the content fade.

## EQ glyph

Already animates via Timer at 30 Hz, independent of phase. Unaffected by this change. Recent linter modification reduced color opacity from 0.85 to 0.60 — keep that.

## Testing

- Manual: launch, play music, skip track, hover. Observe:
  1. Shape morphs smoothly with mild spring overshoot (~0.45s).
  2. Content fades in ~0.1s after shape begins moving.
  3. Faint shadow halo around pill bottom on dark wallpapers.
  4. No vertical jump (constant tR=12 already prevents this).

## Migration

Single PR. No data changes.
