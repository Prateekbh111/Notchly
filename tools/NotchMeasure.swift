import AppKit

guard CommandLine.arguments.count >= 2 else {
    print("usage: swift NotchMeasure.swift <image.png> [<image2.png> ...]")
    exit(1)
}

func measure(_ path: String) {
    guard let image = NSImage(contentsOfFile: path),
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        print("[\(path)] cannot load")
        return
    }

    let W = bitmap.pixelsWide
    let H = bitmap.pixelsHigh

    // Cache pixel-isPill into a flat byte array for speed.
    var mask = [UInt8](repeating: 0, count: W * H)
    let scanH = min(H, 800)
    for y in 0..<scanH {
        for x in 0..<W {
            guard let c = bitmap.colorAt(x: x, y: y) else { continue }
            let brightness = (c.redComponent + c.greenComponent + c.blueComponent) / 3
            if brightness < 0.10 && c.alphaComponent > 0.5 {
                mask[y * W + x] = 1
            }
        }
    }

    @inline(__always) func m(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < W, y >= 0, y < scanH else { return false }
        return mask[y * W + x] == 1
    }

    // Find seed for the pill: scan x ≈ W/2, find first dark row from y = 0.
    // The pill body extends down from menu bar into screen.
    var seedX = W / 2
    var seedY = -1
    for y in 0..<scanH {
        if m(seedX, y) {
            seedY = y
            break
        }
    }
    if seedY == -1 {
        // Try a few offsets in case center column happens to fall in a transparent
        // area like the physical notch cutout itself.
        for dx in stride(from: -200, through: 200, by: 50) {
            for y in 0..<scanH {
                if m(W / 2 + dx, y) {
                    seedX = W / 2 + dx
                    seedY = y
                    break
                }
            }
            if seedY != -1 { break }
        }
    }
    guard seedY != -1 else {
        print("[\(path)] no dark pill region found near top center")
        return
    }

    // BFS flood-fill from seed, restricted to scanH and 8-neighbors.
    var visited = [UInt8](repeating: 0, count: W * H)
    var queue = [(Int, Int)]()
    queue.reserveCapacity(50_000)
    queue.append((seedX, seedY))
    visited[seedY * W + seedX] = 1
    var minX = seedX, maxX = seedX, minY = seedY, maxY = seedY
    var head = 0
    while head < queue.count {
        let (x, y) = queue[head]
        head += 1
        if x < minX { minX = x }
        if x > maxX { maxX = x }
        if y < minY { minY = y }
        if y > maxY { maxY = y }
        for (dx, dy) in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,1),(1,-1),(-1,-1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, nx < W, ny >= 0, ny < scanH else { continue }
            let i = ny * W + nx
            if visited[i] == 0 && mask[i] == 1 {
                visited[i] = 1
                queue.append((nx, ny))
            }
        }
    }

    let pillW = maxX - minX + 1
    let pillH = maxY - minY + 1

    // For each row in the pill bbox, find left/right extent restricted to
    // pixels in the connected component.
    func rowSpanInComponent(_ y: Int) -> Int {
        var l = -1, r = -1
        for x in minX...maxX {
            if visited[y * W + x] == 1 {
                if l == -1 { l = x }
                r = x
            }
        }
        return l == -1 ? 0 : r - l + 1
    }

    var widths: [Int] = []
    let midStart = minY + pillH / 4
    let midEnd = minY + 3 * pillH / 4
    for y in midStart...midEnd {
        let w = rowSpanInComponent(y)
        if w > 0 { widths.append(w) }
    }
    widths.sort()
    let bodyW = widths.isEmpty ? 0 : widths[widths.count / 2]

    let bottomSpan = rowSpanInComponent(maxY)

    // Top inverse corner: shoulder is wider than body. Find first y from top
    // where row width drops to body width — that's how many px the shoulder
    // extends downward = tR (vertical depth).
    var tR = 0
    for y in minY...maxY {
        let span = rowSpanInComponent(y)
        if span > 0 && span <= bodyW + 1 {
            tR = y - minY
            break
        }
    }

    // Lateral shoulder extent — should match tR for a true quarter-circle arc.
    let topSpan = rowSpanInComponent(minY)
    let lateralShoulder = max(0, (topSpan - bodyW) / 2)

    var bR = 0
    for y in stride(from: maxY, through: minY, by: -1) {
        if rowSpanInComponent(y) >= bodyW {
            bR = maxY - y
            break
        }
    }

    // Cross-check: bottom-corner radius from row-width sweep up.
    // Find first row from bottom where width hits bodyW. That's where
    // bottom curve ends. distance from bottom = bR.
    var bRCheck = 0
    for y in stride(from: maxY, through: minY, by: -1) {
        if rowSpanInComponent(y) >= bodyW {
            bRCheck = maxY - y
            break
        }
    }
    _ = bRCheck

    let scale: Double = 2.0
    print("[\(path)]")
    print("  seed:            (\(seedX), \(seedY))")
    print("  pixel bounds:    \(pillW) × \(pillH) px  origin (\(minX), \(minY))")
    print("  body width:      \(bodyW) px")
    print("  top span:        \(rowSpanInComponent(minY)) px (widest row at top)")
    print("  bottom span:     \(bottomSpan) px")
    print("  shoulder lateral:\(lateralShoulder) px each side")
    print("  shoulder vertical(tR depth): \(tR) px")
    print("  bottom R:        \(bR) px")
    print("  --- in points @ 2x ---")
    print("  body W:          \(Double(bodyW) / scale) pt")
    print("  total W (max):   \(Double(max(rowSpanInComponent(minY), bodyW)) / scale) pt")
    print("  pill H:          \(Double(pillH) / scale) pt")
    print("  topInvR (lateral):  \(Double(lateralShoulder) / scale) pt")
    print("  topInvR (vertical): \(Double(tR) / scale) pt")
    print("  bottomR:            \(Double(bR) / scale) pt")
    print()
}

for path in CommandLine.arguments.dropFirst() {
    measure(path)
}
