import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .medium)
    var color: Color = .white
    var speed: Double = 30
    var gap: CGFloat = 32
    var fadeWidth: CGFloat = 16

    @State private var textWidth: CGFloat = 0
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if textWidth <= geo.size.width {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .background(WidthReader(width: $textWidth))
                } else {
                    HStack(spacing: gap) {
                        Text(text).fixedSize().background(WidthReader(width: $textWidth))
                        Text(text).fixedSize()
                    }
                    .font(font)
                    .foregroundStyle(color)
                    .offset(x: animate ? -(textWidth + gap) : 0)
                    .animation(
                        .linear(duration: Double(textWidth + gap) / speed)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
                    .onAppear {
                        animate = false
                        DispatchQueue.main.async { animate = true }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: fadeWidth / max(geo.size.width, 1)),
                        .init(color: .black, location: 1 - fadeWidth / max(geo.size.width, 1)),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
}

private struct WidthReader: View {
    @Binding var width: CGFloat
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: WidthKey.self, value: geo.size.width)
        }
        .onPreferenceChange(WidthKey.self) { width = $0 }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
