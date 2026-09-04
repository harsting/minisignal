import AppKit

/// Verwaltet die aktiven Overlay-Fenster: pro Nachricht ein Fenster,
/// mehrere gleichzeitige Nachrichten laufen auf leicht versetzten Bahnen.
final class OverlayPresenter {

    private final class Slot {
        let window: OverlayWindow
        let animator: CarrierAnimator
        init(window: OverlayWindow, animator: CarrierAnimator) {
            self.window = window
            self.animator = animator
        }
    }

    private var slots: [ObjectIdentifier: Slot] = [:]
    private let sos = SOSOverlay()

    /// Wird gesetzt, damit nach einer eingegangenen Nachricht direkt geantwortet werden kann.
    var onReply: ((String) -> Void)?

    /// Ein Bote trägt die Nachricht über den Bildschirm.
    func deliver(text: String, sender: String, carrier: Carrier, offerReply: Bool = false) {
        let window = OverlayWindow(interactive: false)
        window.present()

        let stage = window.stage
        stage.frame = CGRect(origin: .zero, size: window.frame.size)

        let laneOffset = CGFloat(slots.count % 3) * 46
        let animator = CarrierAnimator(carrier: carrier, text: text, sender: sender)
        let key = ObjectIdentifier(window)
        slots[key] = Slot(window: window, animator: animator)

        Sounds.playArrival()

        animator.run(on: stage, in: window.activeScreenRect, laneOffset: laneOffset) { [weak self] in
            window.orderOut(nil)
            self?.slots[key] = nil
            if offerReply, let reply = self?.onReply {
                ReplyChip.show(peer: sender, onReply: reply)
            }
        }
    }

    func raiseSOS(from sender: String, onSeen: @escaping () -> Void) {
        sos.show(from: sender, onSeen: onSeen)
    }

    func dismissSOS() {
        sos.dismiss(notify: false)
    }
}
