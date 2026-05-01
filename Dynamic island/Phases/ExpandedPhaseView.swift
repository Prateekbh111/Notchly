import SwiftUI
import AppKit
import DynamicIslandCore

struct ExpandedPhaseView: View {
    let snapshot: NowPlayingSnapshot
    let transport: TransportController
    let artNamespace: Namespace.ID
    let width: CGFloat
    let height: CGFloat

    private let outputPicker = OutputPickerController()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                ArtworkView(data: snapshot.track?.artwork)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .matchedGeometryEffect(id: "artwork", in: artNamespace)

                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.track?.title ?? "Not Playing")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let artist = snapshot.track?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer()
                EQGlyphView(isPlaying: snapshot.isPlaying)
                    .frame(width: 28, height: 28)
            }

            ScrubberView(elapsed: snapshot.elapsed, duration: snapshot.track?.duration ?? 0)

            HStack(spacing: 36) {
                Button(action: { transport.toggleShuffle() }) {
                    Image(systemName: "shuffle").font(.system(size: 20))
                }
                Button(action: { transport.previous() }) {
                    Image(systemName: "backward.fill").font(.system(size: 24))
                }
                Button(action: { transport.playPause() }) {
                    Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                }
                Button(action: { transport.next() }) {
                    Image(systemName: "forward.fill").font(.system(size: 24))
                }
                OutputPickerButton(controller: outputPicker)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: width, height: height)
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
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(.white).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 5)

            HStack {
                Text(format(elapsed))
                Spacer()
                Text("-" + format(max(0, duration - elapsed)))
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
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
