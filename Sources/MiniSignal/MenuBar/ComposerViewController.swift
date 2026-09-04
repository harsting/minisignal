import AppKit

/// Inhalt des Menüleisten-Popovers: Nachricht tippen, Boten wählen, abschicken — oder SOS.
final class ComposerViewController: NSViewController {

    /// Text, Boten-Kennung, Empfänger (leer = an alle).
    var onSend: ((String, String?, [String]) -> Void)?
    var onSOS: (([String]) -> Void)?

    private let statusLabel = NSTextField(labelWithString: "")
    private let recipientPicker = NSPopUpButton()
    private let input = NSTextField()
    private let sendButton = NSButton()
    private let sosButton = NSButton()
    private let resultLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(wrappingLabelWithString: "")

    /// Erster Eintrag ist "würfeln", danach alle Boten.
    private let carrierOrder: [Carrier?] = [nil] + Carriers.all
    private var carrierButtons: [NSButton] = []
    private var resultReset: DispatchWorkItem?
    private var selectedRecipientID: String?

    private let buttonsPerRow = 6
    private let buttonSpacing: CGFloat = 4
    private let contentWidth: CGFloat = 296

    override func loadView() {
        let root = NSView()

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor

        recipientPicker.isHidden = true
        recipientPicker.font = .systemFont(ofSize: 12)

        input.placeholderString = "Nachricht …"
        input.font = .systemFont(ofSize: 14)
        input.usesSingleLineMode = true
        input.cell?.wraps = false
        input.cell?.isScrollable = true
        input.target = self
        input.action = #selector(send)

        sendButton.title = "Losschicken"
        sendButton.bezelStyle = .rounded
        sendButton.keyEquivalent = "\r"
        sendButton.target = self
        sendButton.action = #selector(send)

        sosButton.title = "🚨  SOS"
        sosButton.bezelStyle = .rounded
        sosButton.contentTintColor = .systemRed
        sosButton.target = self
        sosButton.action = #selector(sos)
        sosButton.toolTip = "Löst beim anderen sofort ein rot blinkendes Overlay aus"

        resultLabel.font = .systemFont(ofSize: 11)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.lineBreakMode = .byTruncatingTail

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.isHidden = true

        let separator = NSBox()
        separator.boxType = .separator

        let stack = NSStackView(views: [
            statusLabel, recipientPicker, input, makeCarrierGrid(), sendButton,
            separator, sosButton, resultLabel, hintLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            recipientPicker.widthAnchor.constraint(equalToConstant: contentWidth),
            input.widthAnchor.constraint(equalToConstant: contentWidth),
            sendButton.widthAnchor.constraint(equalToConstant: contentWidth),
            separator.widthAnchor.constraint(equalToConstant: contentWidth),
            sosButton.widthAnchor.constraint(equalToConstant: contentWidth),
            resultLabel.widthAnchor.constraint(equalToConstant: contentWidth),
            hintLabel.widthAnchor.constraint(equalToConstant: contentWidth)
        ])

        view = root
        selectCarrier(at: indexOfPreferredCarrier())
    }

    /// Raster aus Emoji-Knöpfen — mit 18 Boten passt keine einzelne Reihe mehr ins Popover.
    private func makeCarrierGrid() -> NSView {
        for (index, carrier) in carrierOrder.enumerated() {
            let button = NSButton(title: carrier?.emoji ?? "🎲",
                                  target: self, action: #selector(carrierTapped))
            button.setButtonType(.pushOnPushOff)
            button.bezelStyle = .regularSquare
            button.font = .systemFont(ofSize: 19)
            button.tag = index
            button.toolTip = carrier?.label ?? "Zufälliger Bote"
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            carrierButtons.append(button)
        }

        // Letzte Reihe mit Platzhaltern auffüllen, damit alle Knöpfe gleich breit bleiben.
        var rows: [NSView] = []
        for start in stride(from: 0, to: carrierButtons.count, by: buttonsPerRow) {
            let end = min(start + buttonsPerRow, carrierButtons.count)
            var items: [NSView] = Array(carrierButtons[start..<end])
            while items.count < buttonsPerRow { items.append(NSView()) }

            let row = NSStackView(views: items)
            row.orientation = .horizontal
            row.spacing = buttonSpacing
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
            rows.append(row)
        }

        let grid = NSStackView(views: rows)
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = buttonSpacing
        return grid
    }

    // MARK: - Zustand von außen

    func focusInput() {
        view.window?.makeFirstResponder(input)
    }

    /// Anwesenheit anzeigen und die Empfängerauswahl nachziehen.
    func setPeers(_ peers: [PeerService.Peer], searching: Bool) {
        if !Settings.shared.isConfigured {
            statusLabel.stringValue = "⚪️  Noch nicht eingerichtet"
        } else if searching {
            statusLabel.stringValue = "⚪️  Suche im WLAN …"
        } else if peers.isEmpty {
            statusLabel.stringValue = "⚪️  Niemand gefunden"
        } else {
            let verb = peers.count == 1 ? "ist" : "sind"
            let names = PeerService.list(peers.map(\.name))
            statusLabel.stringValue = "🟢  \(names) \(verb) da"
        }

        rebuildRecipients(peers)
    }

    private func rebuildRecipients(_ peers: [PeerService.Peer]) {
        // Bei nur einem Gegenüber braucht es keine Auswahl.
        recipientPicker.isHidden = peers.count < 2
        guard peers.count >= 2 else {
            selectedRecipientID = nil
            return
        }

        let previous = selectedRecipientID
        recipientPicker.removeAllItems()
        recipientPicker.addItem(withTitle: "An alle (\(peers.count))")
        recipientPicker.lastItem?.representedObject = nil
        for peer in peers {
            recipientPicker.addItem(withTitle: "Nur an \(peer.name)")
            recipientPicker.lastItem?.representedObject = peer.id
        }
        recipientPicker.target = self
        recipientPicker.action = #selector(recipientChanged)

        if let previous,
           let index = recipientPicker.itemArray.firstIndex(where: {
               $0.representedObject as? String == previous
           }) {
            recipientPicker.selectItem(at: index)
        } else {
            recipientPicker.selectItem(at: 0)
            selectedRecipientID = nil
        }
    }

    @objc private func recipientChanged() {
        selectedRecipientID = recipientPicker.selectedItem?.representedObject as? String
    }

    /// Leer = an alle.
    private func selectedRecipients() -> [String] {
        guard let selectedRecipientID else { return [] }
        return [selectedRecipientID]
    }

    /// Dauerhafter Hinweis unter dem SOS-Knopf, z. B. wenn niemand gefunden wird.
    func setHint(_ text: String?) {
        hintLabel.stringValue = text ?? ""
        hintLabel.isHidden = (text == nil)
    }

    func showResult(_ message: String, ok: Bool) {
        resultReset?.cancel()
        resultLabel.stringValue = message
        resultLabel.textColor = ok ? .secondaryLabelColor : .systemRed
        let reset = DispatchWorkItem { [weak self] in self?.resultLabel.stringValue = "" }
        resultReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: reset)
    }

    // MARK: - Aktionen

    @objc private func send() {
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input.stringValue = ""
        onSend?(text, selectedCarrierID(), selectedRecipients())
    }

    @objc private func sos() {
        onSOS?(selectedRecipients())
    }

    @objc private func carrierTapped(_ sender: NSButton) {
        selectCarrier(at: sender.tag)
        Settings.shared.preferredCarrier = selectedCarrierID()
    }

    private func selectCarrier(at index: Int) {
        for button in carrierButtons {
            button.state = (button.tag == index) ? .on : .off
        }
    }

    private func selectedCarrierID() -> String? {
        guard let button = carrierButtons.first(where: { $0.state == .on }),
              button.tag < carrierOrder.count else { return nil }
        return carrierOrder[button.tag]?.id
    }

    private func indexOfPreferredCarrier() -> Int {
        guard let preferred = Settings.shared.preferredCarrier,
              let index = carrierOrder.firstIndex(where: { $0?.id == preferred }) else { return 0 }
        return index
    }
}
