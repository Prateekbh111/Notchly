import SwiftUI
import Combine

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
