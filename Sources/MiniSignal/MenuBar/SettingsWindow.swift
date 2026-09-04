import AppKit
import ServiceManagement

/// Kleines Einstellungsfenster — beim ersten Start auch die Einrichtung.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    var onSaved: (() -> Void)?

    private let nameField = NSTextField()
    private let codeField = NSTextField()
    private let soundsCheck = NSButton(checkboxWithTitle: "Töne abspielen", target: nil, action: nil)
    private let hotkeyCheck = NSButton(checkboxWithTitle: "Kurzbefehl zum Öffnen", target: nil, action: nil)
    private let hotkeyButton = HotkeyRecorderButton(title: Settings.shared.hotkeyDisplay)
    private var pendingHotkey: (code: UInt32, modifiers: UInt32, display: String)?
    private let loginCheck = NSButton(checkboxWithTitle: "Beim Anmelden starten", target: nil, action: nil)
    private let hint = NSTextField(wrappingLabelWithString: "")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MiniSignal"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let window else { return }
        window.delegate = self

        let title = NSTextField(labelWithString: "Einrichtung")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let explanation = NSTextField(wrappingLabelWithString:
            "Der Paar-Code muss auf beiden Macs exakt gleich sein. Er verschlüsselt eure "
            + "Nachrichten und sorgt dafür, dass sonst niemand im WLAN mitschreiben kann.")
        explanation.font = .systemFont(ofSize: 12)
        explanation.textColor = .secondaryLabelColor

        nameField.placeholderString = "Dein Name, z. B. Marvin"
        nameField.stringValue = Settings.shared.displayName
        codeField.placeholderString = "Paar-Code, z. B. rosengarten-42"
        codeField.stringValue = Settings.shared.pairingCode

        soundsCheck.state = Settings.shared.soundsEnabled ? .on : .off

        hotkeyCheck.state = Settings.shared.hotkeyEnabled ? .on : .off
        hotkeyCheck.target = self
        hotkeyCheck.action = #selector(hotkeyToggled)
        hotkeyButton.isEnabled = Settings.shared.hotkeyEnabled
        hotkeyButton.toolTip = "Klicken, dann die gewünschte Tastenkombination drücken"
        hotkeyButton.onCapture = { [weak self] keyCode, flags, characters in
            guard let self else { return }
            let display = HotkeyManager.describe(keyCode: keyCode, flags: flags,
                                                 characters: characters)
            self.pendingHotkey = (UInt32(keyCode),
                                  HotkeyManager.carbonModifiers(from: flags),
                                  display)
            self.hotkeyButton.setRestingTitle(display)
        }
        loginCheck.state = SettingsWindowController.launchesAtLogin ? .on : .off

        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let save = NSButton(title: "Sichern", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"

        let stack = NSStackView(views: [
            title, explanation,
            labelled("Name", nameField),
            labelled("Paar-Code", codeField),
            soundsCheck, hotkeyRow(), loginCheck, hint, save
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
            explanation.widthAnchor.constraint(equalToConstant: 376),
            hint.widthAnchor.constraint(equalToConstant: 376)
        ])
        window.contentView = content
    }

    private func hotkeyRow() -> NSView {
        hotkeyButton.translatesAutoresizingMaskIntoConstraints = false
        hotkeyButton.widthAnchor.constraint(equalToConstant: 190).isActive = true

        let row = NSStackView(views: [hotkeyCheck, hotkeyButton])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        return row
    }

    @objc private func hotkeyToggled() {
        hotkeyButton.isEnabled = hotkeyCheck.state == .on
    }

    private func labelled(_ caption: String, _ field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: caption)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 376).isActive = true

        let stack = NSStackView(views: [label, field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = codeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard code.count >= 4 else {
            hint.stringValue = "Bitte einen Paar-Code mit mindestens 4 Zeichen wählen."
            hint.textColor = .systemRed
            return
        }

        if !name.isEmpty { Settings.shared.displayName = name }
        Settings.shared.pairingCode = code
        Settings.shared.soundsEnabled = soundsCheck.state == .on
        Settings.shared.hotkeyEnabled = hotkeyCheck.state == .on
        if let pendingHotkey {
            Settings.shared.hotkeyKeyCode = pendingHotkey.code
            Settings.shared.hotkeyModifiers = pendingHotkey.modifiers
            Settings.shared.hotkeyDisplay = pendingHotkey.display
            self.pendingHotkey = nil
        }
        SettingsWindowController.setLaunchesAtLogin(loginCheck.state == .on)

        hint.stringValue = "Gesichert."
        hint.textColor = .secondaryLabelColor
        onSaved?()
        window?.performClose(nil)
    }

    // MARK: - Start bei der Anmeldung

    static var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("MiniSignal: Anmeldeobjekt konnte nicht gesetzt werden: \(error)")
        }
    }
}
