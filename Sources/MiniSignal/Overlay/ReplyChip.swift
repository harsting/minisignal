import AppKit

/// Kleines Antwortfeld unten rechts, das nach einer eingegangenen Nachricht auftaucht.
/// Verschwindet von selbst, wenn niemand hineintippt.
final class ReplyChip: NSViewController {

    private let peer: String
    private let onReply: (String) -> Void

    private var window: OverlayWindow?
    private var autoClose: DispatchWorkItem?
    private let input = NSTextField()

    private static var current: ReplyChip?

    init(peer: String, onReply: @escaping (String) -> Void) {
        self.peer = peer
        self.onReply = onReply
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    static func show(peer: String, onReply: @escaping (String) -> Void) {
        current?.close()
        let chip = ReplyChip(peer: peer, onReply: onReply)
        current = chip
        chip.present()
    }

    private func present() {
        let size = NSSize(width: 360, height: 118)
        guard let screen = OverlayWindow.screenUnderPointer() else { return }
        let frame = NSRect(x: screen.frame.maxX - size.width - 28,
                           y: screen.frame.minY + 96,
                           width: size.width, height: size.height)
        let window = OverlayWindow(interactive: true, frame: frame)

        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 16
        blur.layer?.masksToBounds = true

        let title = NSTextField(labelWithString: "Antwort an \(peer)")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        input.placeholderString = "Kurz zurückschreiben …"
        input.font = .systemFont(ofSize: 14)
        input.target = self
        input.action = #selector(sendReply)

        let hint = NSTextField(labelWithString: "⏎ senden · esc schließen")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, input, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
            input.widthAnchor.constraint(equalToConstant: size.width - 32)
        ])

        window.contentView = blur
        window.orderFrontRegardless()
        self.window = window

        let close = DispatchWorkItem { [weak self] in self?.closeIfUntouched() }
        autoClose = close
        DispatchQueue.main.asyncAfter(deadline: .now() + 14, execute: close)
    }

    @objc private func sendReply() {
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { close(); return }
        onReply(text)
        close()
    }

    private func closeIfUntouched() {
        guard input.stringValue.isEmpty else {
            // Es wird gerade getippt — noch etwas Zeit lassen.
            let again = DispatchWorkItem { [weak self] in self?.closeIfUntouched() }
            autoClose = again
            DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: again)
            return
        }
        close()
    }

    func close() {
        autoClose?.cancel()
        autoClose = nil
        window?.orderOut(nil)
        window = nil
        if ReplyChip.current === self { ReplyChip.current = nil }
    }
}
