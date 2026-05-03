import SwiftUI
import AppKit
import NotchlyCore

struct ExpandedPhaseView: View {
    let snapshot: NowPlayingSnapshot
    let transport: TransportController
    let artNamespace: Namespace.ID
    let width: CGFloat
    let height: CGFloat
    let notchInset: CGFloat

    private let outputPicker = OutputPickerController()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Color.clear
                    .frame(width: 56, height: 56)
                    .matchedGeometryEffect(id: "artwork", in: artNamespace, isSource: true)

                VStack(alignment: .leading, spacing: 2) {
                    Spacer()
                    Text(snapshot.track?.title ?? "Not Playing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let artist = snapshot.track?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Color.clear
                    .frame(width: 22, height: 22)
                    .matchedGeometryEffect(id: "eq", in: artNamespace, isSource: true)
            }

            ScrubberView(elapsed: snapshot.elapsed, duration: snapshot.track?.duration ?? 0)

            HStack {
//                Button(action: { transport.toggleShuffle() }) {
//                    Image(systemName: "shuffle").font(.system(size: 16))
//                }
//                .opacity(0.4).padding(.trailing, 20)
                HStack(spacing: 26) {
                    Button(action: { transport.previous() }) {
                        Image(systemName: "backward.fill").font(.system(size: 23)).opacity(0.7)
                    }
                    .buttonStyle(TransportButtonStyle())
                    Button(action: { transport.playPause() }) {
                        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .regular)).opacity(0.7)
                    }
                    .buttonStyle(TransportButtonStyle(diameter: 48))
                    Button(action: { transport.next() }) {
                        Image(systemName: "forward.fill").font(.system(size: 23)).opacity(0.7)
                    }
                    .buttonStyle(TransportButtonStyle())
                }
//                OutputPickerButton(controller: outputPicker)
//                    .frame(width: 40, height: 40)
//                    .opacity(0.4).padding(.leading, 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, notchInset-10)
        .padding(.horizontal, 20)
        .padding(.bottom, 25)
        .frame(width: width, height: height)
    }
}

private struct TransportButtonStyle: ButtonStyle {
    var diameter: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        Label(configuration: configuration, diameter: diameter)
    }

    private struct Label: View {
        let configuration: Configuration
        let diameter: CGFloat
        @State private var hovering = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(hovering ? 0.15 : 0))
                        .frame(width: diameter, height: diameter)
                )
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
        }
    }
}

private struct OutputPickerButton: NSViewRepresentable {
    let controller: OutputPickerController

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Audio output")
        button.contentTintColor = .white
        button.target = context.coordinator
        button.action = #selector(Coordinator.click(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    @MainActor
    final class Coordinator: NSObject {
        let controller: OutputPickerController
        init(controller: OutputPickerController) { self.controller = controller }

        @objc func click(_ sender: NSButton) {
            let location = NSPoint(x: 0, y: sender.bounds.height + 4)
            controller.presentMenu(at: location, in: sender)
        }
    }
}

private struct ScrubberView: View {
    let elapsed: TimeInterval
    let duration: TimeInterval

    var body: some View {
        HStack{
            Text(format(elapsed)).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(.white.opacity(0.80)).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)
            
        }
            Text("-" + format(max(0, duration - elapsed))).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
        }
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, elapsed / duration)))
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
