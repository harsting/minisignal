import AppKit

/// Icon in der Menüleiste plus das Popover mit dem Eingabefeld.
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    let composer = ComposerViewController()

    var onSettings: (() -> Void)?
    var onInvite: (() -> Void)?
    var onSelfTest: (() -> Void)?

    override init() {
        super.init()

        if let button = statusItem.button {
            button.title = "💌"
            button.toolTip = "MiniSignal"
            button.target = self
            button.action = #selector(buttonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.contentViewController = composer
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    /// Klingelzeichen am Icon, wenn etwas angekommen ist.
    func flashIcon() {
        guard let button = statusItem.button else { return }
        button.title = "💞"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { button.title = "💌" }
    }

    func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in self?.composer.focusInput() }
    }

    @objc private func buttonClicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        if isRightClick { showMenu() } else { togglePopover() }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Einstellungen …", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(withTitle: "Jemanden einladen …", action: #selector(invite), keyEquivalent: "i")
            .target = self
        menu.addItem(withTitle: "Testnachricht an mich", action: #selector(selfTest), keyEquivalent: "t")
            .target = self
        let recent = History.all()
        if !recent.isEmpty {
            menu.addItem(.separator())
            let header = menu.addItem(withTitle: "Letzte Nachrichten", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM. HH:mm"
            for entry in recent {
                let arrow = entry.incoming ? "←" : "→"
                let title = "\(arrow) \(formatter.string(from: entry.at))  \(entry.text)"
                let item = submenu.addItem(withTitle: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
            }
            header.submenu = submenu
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "MiniSignal beenden", action: #selector(quit), keyEquivalent: "q")
            .target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() { onSettings?() }
    @objc private func invite() { onInvite?() }
    @objc private func selfTest() { onSelfTest?() }
    @objc private func quit() { NSApp.terminate(nil) }
}
