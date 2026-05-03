import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggle: (Bool) -> Void
    private let enabledKey = "com.notchly.enabled"

    private(set) var isEnabled: Bool

    init(onToggle: @escaping (Bool) -> Void) {
        self.onToggle = onToggle
        self.isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        rebuildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "rectangle.tophalf.inset.filled",
            accessibilityDescription: "Notchly"
        )
        button.image?.isTemplate = true
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: isEnabled ? "Disable Notchly" : "Enable Notchly",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = isEnabled ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        rebuildMenu()
        onToggle(isEnabled)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
