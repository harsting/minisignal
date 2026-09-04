import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: StatusItemController!
    private let overlays = OverlayPresenter()
    private let peers = PeerService()
    private var settings: SettingsWindowController?
    private var hotkey: Hotkey?

    private var me: String { Settings.shared.displayName }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController()

        statusItem.composer.onSend = { [weak self] text, carrierID in
            self?.sendMessage(text: text, carrierID: carrierID)
        }
        statusItem.composer.onSOS = { [weak self] in self?.sendSOS() }
        statusItem.onSettings = { [weak self] in self?.openSettings() }
        statusItem.onSelfTest = { [weak self] in self?.previewLocally() }

        overlays.onReply = { [weak self] text in self?.sendMessage(text: text, carrierID: nil) }
        peers.onPresence = { [weak self] presence in self?.show(presence) }
        peers.onEnvelope = { [weak self] envelope in self?.handle(envelope) }

        hotkey = Hotkey { [weak self] in self?.statusItem.togglePopover() }

        show(.searching)
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

    private func sendMessage(text: String, carrierID: String?) {
        let envelope = Envelope(kind: .message, text: text, sender: me, carrier: carrierID)
        statusItem.composer.showResult("Bote unterwegs …", ok: true)

        peers.send(envelope) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                Sounds.playSent()
                History.add(text: text, who: self.peers.peerDisplayName, incoming: false)
                self.statusItem.composer.showResult("Angekommen ✓", ok: true)
            case .failure(let error):
                self.statusItem.composer.showResult(error.localizedDescription, ok: false)
            }
        }
    }

    private func sendSOS() {
        let envelope = Envelope(kind: .sos, sender: me)
        statusItem.composer.showResult("SOS unterwegs …", ok: true)

        peers.send(envelope) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.statusItem.composer.showResult("SOS zugestellt — warte auf Quittung", ok: true)
            case .failure(let error):
                self.statusItem.composer.showResult(error.localizedDescription, ok: false)
            }
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
            overlays.raiseSOS(from: envelope.sender) { [weak self] in
                guard let self else { return }
                self.peers.sendQuietly(Envelope(kind: .seen, sender: self.me))
            }
            statusItem.flashIcon()

        case .seen:
            statusItem.composer.showResult("✓ \(envelope.sender) hat das SOS gesehen", ok: true)

        case .ack:
            break
        }
    }

    private func show(_ presence: PeerService.Presence) {
        switch presence {
        case .notPaired:
            statusItem.composer.setPresence("Noch nicht eingerichtet", online: false)
        case .searching:
            statusItem.composer.setPresence("Suche im WLAN …", online: false)
        case .online(let name):
            statusItem.composer.setPresence("\(name) ist da", online: true)
            statusItem.composer.setHint(nil)
        case .offline:
            statusItem.composer.setPresence("Niemand gefunden", online: false)
            statusItem.composer.setHint(
                "Läuft MiniSignal auf dem anderen Mac? Sonst prüfen: Systemeinstellungen → "
                + "Datenschutz & Sicherheit → Lokales Netzwerk.")
        }
    }

    // MARK: - Sonstiges

    private func openSettings() {
        if settings == nil {
            let controller = SettingsWindowController()
            controller.onSaved = { [weak self] in self?.peers.restart() }
            settings = controller
        }
        settings?.present()
    }

    /// Zeigt einen Boten nur auf dem eigenen Bildschirm — zum Ausprobieren.
    private func previewLocally() {
        overlays.deliver(text: "Testnachricht — sieht das gut aus?",
                         sender: me,
                         carrier: Carriers.with(id: Settings.shared.preferredCarrier))
    }

    /// Nur für Tests: MINISIGNAL_DEMO zeigt einen Boten lokal,
    /// MINISIGNAL_SEND verschickt eine echte Nachricht an die Gegenstelle.
    private func runDemoIfRequested() {
        let env = ProcessInfo.processInfo.environment

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
                NSLog("MiniSignal: sende Testnachricht, Präsenz = \(self.peers.presence)")
                self.peers.send(envelope) { result in
                    NSLog("MiniSignal: Ergebnis = \(result)")
                }
            }
        }

        let seconds = Double(env["MINISIGNAL_DEMO_SECONDS"] ?? "") ?? 25
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
    }
}
