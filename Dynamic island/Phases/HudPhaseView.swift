import SwiftUI

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

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35))
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: (rightWidth-20) * CGFloat(max(0, min(1, state.level))))
            }
            .frame(width: rightWidth-20, height: 6)
            .frame(height: height)
            .padding(.horizontal, 5)
        }
        .frame(width: leftWidth + notchWidth + rightWidth, height: height)
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
        }
    }
}
