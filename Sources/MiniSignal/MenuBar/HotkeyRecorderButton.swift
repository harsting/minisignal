import AppKit
import Carbon.HIToolbox

/// Knopf, der auf Klick die nächste Tastenkombination aufnimmt.
final class HotkeyRecorderButton: NSButton {

    /// Liefert Tastencode, Modifier und die Zeichen der gedrückten Taste.
    var onCapture: ((UInt16, NSEvent.ModifierFlags, String?) -> Void)?

    private var isRecording = false
    private var restingTitle = ""

    init(title: String) {
        super.init(frame: .zero)
        self.restingTitle = title
        self.title = title
        bezelStyle = .rounded
        target = self
        action = #selector(startRecording)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    func setRestingTitle(_ text: String) {
        restingTitle = text
        if !isRecording { title = text }
    }

    @objc private func startRecording() {
        isRecording = true
        title = "Taste drücken …"
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
        title = restingTitle
    }

    /// Fängt auch Kombinationen ab, die sonst ein Menü auslösen würden (z. B. ⌘Q).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        handle(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        handle(event)
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.isEmpty else {
            title = "Bitte mit ⌘ ⌥ ⌃ oder ⇧ …"
            return
        }

        stopRecording()
        onCapture?(event.keyCode, flags, event.charactersIgnoringModifiers)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { stopRecording() }
        return super.resignFirstResponder()
    }
}
