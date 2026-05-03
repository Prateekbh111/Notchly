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
                    .frame(width: 28, height: 28)
                    .frame(maxWidth: .infinity, alignment: .center)
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
                .stroke(.white.opacity(0.22), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, level))))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(round(level * 100)))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
        }
    }

    private var ringColor: Color {
        if level <= 0.20 { return .red.opacity(0.95) }
        if level <= 0.40 { return .yellow.opacity(0.95) }
        return Color(red: 0.30, green: 0.85, blue: 0.40)
    }
}
