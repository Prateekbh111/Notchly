import SwiftUI

struct HudPhaseView: View {
    let state: SystemHUDState
    let width: CGFloat
    let height: CGFloat
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // Left of notch — icon
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
                .contentTransition(.symbolEffect(.replace))

            // Notch hardware sits here
            Color.clear.frame(width: notchWidth)

            // Right of notch — scrubber
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, state.level))))
                }
            }
            .frame(height: 7)
            .frame(maxWidth: 50, alignment: .center)
            .padding(.horizontal, 10)
        }
        .frame(width: width, height: height)
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
