import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: StatusItemController!
    private let overlays = OverlayPresenter()
    private let peers = PeerService()
    private var settings: SettingsWindowController?
    private var invite: InviteWindowController?
    private var hotkey: HotkeyManager?

    private var me: String { Settings.shared.displayName }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Beitritts-Links der Form minisignal://join?code=…&from=…
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:with:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController()

        statusItem.composer.onSend = { [weak self] text, carrierID, recipients in
            self?.sendMessage(text: text, carrierID: carrierID, recipientIDs: recipients)
        }
        statusItem.composer.onSOS = { [weak self] recipients in
            self?.sendSOS(recipientIDs: recipients)
        }
        statusItem.onSettings = { [weak self] in self?.openSettings() }
        statusItem.onInvite = { [weak self] in self?.openInvite() }
        statusItem.onSelfTest = { [weak self] in self?.previewLocally() }

        overlays.onReply = { [weak self] text in
            self?.sendMessage(text: text, carrierID: nil, recipientIDs: [])
        }
        peers.onPeersChanged = { [weak self] list, searching in
            self?.showPeers(list, searching: searching)
        }
        peers.onEnvelope = { [weak self] envelope in self?.handle(envelope) }

        hotkey = HotkeyManager { [weak self] in self?.statusItem.togglePopover() }

        showPeers([], searching: true)
        peers.start()

        if !Settings.shared.isConfigured {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openSettings()
            }
        }

        runDemoIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        peers.stop()
    }

    // MARK: - Senden

    private func targets(for ids: [String]) -> [PeerService.Peer] {
        ids.compactMap { peers.peer(withID: $0) }
    }

    private func sendMessage(text: String, carrierID: String?, recipientIDs: [String]) {
        let envelope = Envelope(kind: .message, text: text, sender: me, carrier: carrierID)
        statusItem.composer.showResult("Bote unterwegs …", ok: true)

        peers.send(envelope, to: targets(for: recipientIDs)) { [weak self] report in
            guard let self else { return }
            if !report.delivered.isEmpty {
                Sounds.playSent()
                History.add(text: text, who: PeerService.list(report.delivered), incoming: false)
            }
            self.statusItem.composer.showResult(report.summary,
                                                ok: !report.allFailed && !report.delivered.isEmpty)
        }
    }

    private func sendSOS(recipientIDs: [String]) {
        let envelope = Envelope(kind: .sos, sender: me)
        statusItem.composer.showResult("SOS unterwegs …", ok: true)

        peers.send(envelope, to: targets(for: recipientIDs)) { [weak self] report in
            guard let self else { return }
            let text = report.delivered.isEmpty
                ? report.summary
                : "SOS bei \(PeerService.list(report.delivered)) — warte auf Quittung"
            self.statusItem.composer.showResult(text, ok: !report.delivered.isEmpty)
        }
    }

    // MARK: - Empfangen

    private func handle(_ envelope: Envelope) {
        switch envelope.kind {
        case .message:
            overlays.deliver(text: envelope.text,
                             sender: envelope.sender,
                             carrier: Carriers.with(id: envelope.carrier),
                             offerReply: true)
            History.add(text: envelope.text, who: envelope.sender, incoming: true)
            statusItem.flashIcon()

        case .sos:
            let origin = peers.peer(withID: envelope.senderID)
            overlays.raiseSOS(from: envelope.sender) { [weak self] in
                guard let self else { return }
                self.peers.sendQuietly(Envelope(kind: .seen, sender: self.me), to: origin)
            }
            statusItem.flashIcon()

        case .seen:
            statusItem.composer.showResult("✓ \(envelope.sender) hat das SOS gesehen", ok: true)

        case .ack:
            break
        }
    }

    private func showPeers(_ list: [PeerService.Peer], searching: Bool) {
        statusItem.composer.setPeers(list, searching: searching)

        if list.isEmpty && !searching && Settings.shared.isConfigured {
            statusItem.composer.setHint(
                "Läuft MiniSignal auf dem anderen Gerät? Sonst prüfen: Systemeinstellungen → "
                + "Datenschutz & Sicherheit → Lokales Netzwerk.")
        } else {
            statusItem.composer.setHint(nil)
        }
    }

    // MARK: - Einladung annehmen

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor,
                                      with replyEvent: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string),
              url.scheme == Invite.scheme else { return }

        guard url.host == "join",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let code = items.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return }

        let from = items.first(where: { $0.name == "from" })?.value ?? "Jemand"
        DispatchQueue.main.async { [weak self] in self?.confirmJoin(code: code, from: from) }
    }

    private func confirmJoin(code: String, from: String) {
        NSApp.activate(ignoringOtherApps: true)

        if code == Settings.shared.pairingCode {
            let done = NSAlert()
            done.messageText = "Ihr seid schon verbunden"
            done.informativeText = "Dieser Paar-Code ist bereits eingetragen."
            done.addButton(withTitle: "Alles klar")
            done.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "\(from) lädt dich zu MiniSignal ein"
        alert.informativeText = Settings.shared.isConfigured
            ? "Möchtest du den Paar-Code übernehmen? Deine bisherige Verbindung wird "
              + "dadurch ersetzt — die Geräte mit dem alten Code erreichst du danach nicht mehr."
            : "Möchtest du den Paar-Code übernehmen und MiniSignal einrichten?"
        alert.addButton(withTitle: "Übernehmen")
        alert.addButton(withTitle: "Abbrechen")
        alert.alertStyle = .informational

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Settings.shared.pairingCode = code
        peers.restart()
        openSettings()
    }

    // MARK: - Sonstiges

    private func openSettings() {
        if settings == nil {
            let controller = SettingsWindowController()
            controller.onSaved = { [weak self] in
                guard let self else { return }
                self.peers.restart()
                if self.hotkey?.apply() == false { self.reportHotkeyConflict() }
            }
            settings = controller
        }
        settings?.present()
    }

    private func reportHotkeyConflict() {
        let alert = NSAlert()
        alert.messageText = "Kurzbefehl ist schon vergeben"
        alert.informativeText = "\(Settings.shared.hotkeyDisplay) wird bereits von macOS oder "
            + "einer anderen App benutzt. Wähl in den Einstellungen eine andere Kombination — "
            + "bis dahin öffnest du MiniSignal über das 💌 in der Menüleiste."
        alert.addButton(withTitle: "Alles klar")
        alert.runModal()
    }

    private func openInvite() {
        guard Settings.shared.isConfigured else {
            let alert = NSAlert()
            alert.messageText = "Erst einen Paar-Code festlegen"
            alert.informativeText = "Die Einladung enthält euren Paar-Code — den gibt es "
                + "noch nicht. Trag ihn in den Einstellungen ein."
            alert.addButton(withTitle: "Einstellungen öffnen")
            alert.addButton(withTitle: "Abbrechen")
            if alert.runModal() == .alertFirstButtonReturn { openSettings() }
            return
        }

        if invite == nil { invite = InviteWindowController() }
        invite?.present()
    }

    /// Zeigt einen Boten nur auf dem eigenen Bildschirm — zum Ausprobieren.
    private func previewLocally() {
        overlays.deliver(text: "Testnachricht — sieht das gut aus?",
                         sender: me,
                         carrier: Carriers.with(id: Settings.shared.preferredCarrier))
    }

    /// Nur für Tests: MINISIGNAL_DEMO zeigt einen Boten lokal,
    /// MINISIGNAL_SEND verschickt eine echte Nachricht an alle Gegenstellen.
    private func runDemoIfRequested() {
        let env = ProcessInfo.processInfo.environment

        if env["MINISIGNAL_DIAGNOSE"] != nil {
            Diagnose.run()
            NSApp.terminate(nil)
            return
        }

        if let sheet = env["MINISIGNAL_SPRITESHEET"] {
            if let list = env["MINISIGNAL_SPRITESHEET_EMOJI"], !list.isEmpty {
                SpriteSheet.writeEmoji(list.components(separatedBy: ","), to: sheet)
            } else {
                SpriteSheet.write(to: sheet)
            }
            NSApp.terminate(nil)
            return
        }

        let demo = env["MINISIGNAL_DEMO"]
        let outgoing = env["MINISIGNAL_SEND"]
        guard demo != nil || outgoing != nil else { return }

        if let demo, outgoing == nil {
            let text = env["MINISIGNAL_DEMO_TEXT"] ?? "Kaffee ist fertig, kommst du hoch? ☕️"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                if demo == "popover" {
                    self.statusItem.showPopover()
                } else if demo == "settings" {
                    self.openSettings()
                } else if demo == "invite" {
                    self.openInvite()
                } else if demo == "sos" {
                    self.overlays.raiseSOS(from: "Testfrau") {}
                } else {
                    self.overlays.deliver(text: text, sender: "Testfrau",
                                          carrier: Carriers.with(id: demo))
                }
            }
        }

        if let outgoing {
            let kind: Envelope.Kind = env["MINISIGNAL_SEND_KIND"] == "sos" ? .sos : .message
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self else { return }
                let envelope = Envelope(kind: kind, text: outgoing, sender: self.me, carrier: demo)
                NSLog("MiniSignal: sende Testnachricht an \(self.peers.peers.count) Gerät(e)")
                self.peers.send(envelope) { report in
                    NSLog("MiniSignal: Ergebnis = \(report.summary)")
                }
            }
        }

        let seconds = Double(env["MINISIGNAL_DEMO_SECONDS"] ?? "") ?? 25
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
    }
}
