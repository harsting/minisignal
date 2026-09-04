import AppKit

/// Erzeugt den Einladungstext samt Download- und Beitritts-Link und legt ihn
/// in die Zwischenablage.
enum Invite {

    static let scheme = "minisignal"

    /// minisignal://join?code=…&from=…
    static func joinLink(code: String, from: String) -> String {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "join"
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "from", value: from)
        ]
        return components.string ?? ""
    }

    static func text() -> String {
        let settings = Settings.shared
        let code = settings.pairingCode
        let me = settings.displayName

        // Fließtext ohne harte Umbrüche — so sieht die Einladung in Mail,
        // WhatsApp oder iMessage nach dem Einfügen richtig aus.
        let intro = "MiniSignal ist eine kleine App für die Menüleiste: Du tippst eine kurze "
            + "Nachricht, und drüben trägt sie ein Tier über den Desktop — eine Schildkröte, ein "
            + "hüpfender Hase, ein Flugzeug mit Schleppbanner. Dazu ein SOS-Knopf, der beim "
            + "anderen den Bildschirm rot blinken lässt. Läuft nur über euer WLAN: kein Server, "
            + "kein Konto, nichts im Internet."

        let gatekeeper = "Beim allerersten Start: Rechtsklick auf MiniSignal → \"Öffnen\" → "
            + "nochmal \"Öffnen\". Die App ist nicht bei Apple registriert, deshalb fragt macOS "
            + "einmal nach. Danach startet sie ganz normal. Wer lieber selbst baut: \(settings.repoURL)"

        let network = "3) macOS fragt einmal, ob MiniSignal ins lokale Netzwerk darf. Erlauben — "
            + "sonst finden sich die Geräte nicht."

        return """
        \(me) lädt dich zu MiniSignal ein 💌

        \(intro)

        1) App laden und nach "Programme" ziehen:
        \(settings.downloadURL)

        \(gatekeeper)

        2) MiniSignal öffnen, dann diesen Link anklicken — er trägt den Code gleich ein:
        \(joinLink(code: code, from: me))

        Von Hand geht auch: in den Einstellungen als Paar-Code eintragen: \(code)

        \(network)

        Danach liegt 💌 oben in der Menüleiste. Bis gleich!
        """
    }

    static func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

/// Fenster, das den Einladungstext zeigt und zum Kopieren anbietet.
final class InviteWindowController: NSWindowController {

    private let textView = NSTextView()
    private let copyTextButton = NSButton()
    private let copyLinkButton = NSButton()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Einladung"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let window else { return }

        let title = NSTextField(labelWithString: "Einladung verschicken")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let warning = NSTextField(wrappingLabelWithString:
            "⚠️  Im Text steht euer Paar-Code. Wer ihn hat, kann mitschreiben und "
            + "mitlesen — schick die Einladung also nur an Leute, die wirklich "
            + "dazugehören sollen. Wer einen eigenen, neuen Code einträgt, bildet "
            + "einen eigenen Kreis und hat mit euch nichts zu tun.")
        warning.font = .systemFont(ofSize: 11)
        warning.textColor = .secondaryLabelColor

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 320).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 516).isActive = true

        copyTextButton.title = "Ganzen Text kopieren"
        copyTextButton.bezelStyle = .rounded
        copyTextButton.keyEquivalent = "\r"
        copyTextButton.target = self
        copyTextButton.action = #selector(copyEverything)

        copyLinkButton.title = "Nur den Beitritts-Link"
        copyLinkButton.bezelStyle = .rounded
        copyLinkButton.target = self
        copyLinkButton.action = #selector(copyLink)

        let buttons = NSStackView(views: [copyTextButton, copyLinkButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10

        let stack = NSStackView(views: [title, warning, scroll, buttons])
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
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            warning.widthAnchor.constraint(equalToConstant: 516)
        ])
        window.contentView = content
    }

    func present() {
        textView.string = Invite.text()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func copyEverything() {
        Invite.copyToClipboard(Invite.text())
        flash(copyTextButton, restoring: "Ganzen Text kopieren")
    }

    @objc private func copyLink() {
        Invite.copyToClipboard(Invite.joinLink(code: Settings.shared.pairingCode,
                                               from: Settings.shared.displayName))
        flash(copyLinkButton, restoring: "Nur den Beitritts-Link")
    }

    private func flash(_ button: NSButton, restoring title: String) {
        button.title = "Kopiert ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { button.title = title }
    }
}
