import AppKit

/// Klickbare Sicht, die Maus- und ESC-Eingaben an eine Closure weiterreicht.
final class ClickCatcherView: NSView {
    var onDismiss: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { onDismiss?() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || event.keyCode == 36 { onDismiss?() }  // ESC oder ⏎
        else { super.keyDown(with: event) }
    }
}

/// Rot pulsierendes Overlay — ein eigenes Fenster pro Bildschirm, jedes exakt so
/// groß wie sein Monitor. Klick oder ESC quittiert und meldet "gesehen" zurück.
final class SOSOverlay {

    private var windows: [OverlayWindow] = []
    private var timeout: DispatchWorkItem?
    private var onSeen: (() -> Void)?

    private let holdSeconds: TimeInterval = 20

    func show(from sender: String, onSeen: @escaping () -> Void) {
        dismiss(notify: false)
        self.onSeen = onSeen

        let focusScreen = NSScreen.main ?? NSScreen.screens.first
        var keyWindow: OverlayWindow?
        var keyCatcher: ClickCatcherView?

        for screen in NSScreen.screens {
            let window = OverlayWindow(interactive: true, frame: screen.frame)
            let bounds = CGRect(origin: .zero, size: screen.frame.size)

            let catcher = ClickCatcherView(frame: bounds)
            catcher.wantsLayer = true
            catcher.autoresizingMask = [.width, .height]
            catcher.onDismiss = { [weak self] in self?.dismiss(notify: true) }
            window.contentView = catcher

            guard let stage = catcher.layer else { continue }
            stage.frame = bounds

            stage.addSublayer(makeWash(in: bounds))
            stage.addSublayer(makeBorder(in: bounds))

            if screen == focusScreen {
                stage.addSublayer(makeCard(sender: sender, in: bounds))
                keyWindow = window
                keyCatcher = catcher
            }

            window.present()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        if let keyWindow, let keyCatcher {
            keyWindow.makeKeyAndOrderFront(nil)
            keyWindow.makeFirstResponder(keyCatcher)
        }

        Sounds.playSOS()

        let work = DispatchWorkItem { [weak self] in self?.dismiss(notify: false) }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdSeconds, execute: work)
    }

    func dismiss(notify: Bool) {
        timeout?.cancel()
        timeout = nil
        Sounds.stopSOS()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        if notify { onSeen?() }
        onSeen = nil
    }

    // MARK: - Bausteine

    private func makeWash(in bounds: CGRect) -> CALayer {
        let wash = CALayer()
        wash.frame = bounds
        wash.backgroundColor = NSColor(calibratedRed: 0.85, green: 0.05, blue: 0.10, alpha: 1).cgColor
        wash.opacity = 0.16
        wash.add(pulse(from: 0.10, to: 0.34), forKey: "pulse")
        return wash
    }

    private func makeBorder(in bounds: CGRect) -> CALayer {
        let border = CAShapeLayer()
        let inset = bounds.insetBy(dx: 22, dy: 22)
        border.frame = bounds
        border.path = CGPath(roundedRect: inset, cornerWidth: 26, cornerHeight: 26, transform: nil)
        border.strokeColor = NSColor(calibratedRed: 1.0, green: 0.12, blue: 0.18, alpha: 1).cgColor
        border.lineWidth = 44
        border.fillColor = nil
        border.shadowColor = NSColor.red.cgColor
        border.shadowOpacity = 0.9
        border.shadowRadius = 30
        border.shadowOffset = .zero
        border.add(pulse(from: 0.35, to: 1.0), forKey: "pulse")
        return border
    }

    private func makeCard(sender: String, in bounds: CGRect) -> CALayer {
        let card = CALayer()
        let image = SOSOverlay.cardImage(sender: sender)
        card.contents = image
        card.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        card.bounds = CGRect(origin: .zero, size: image.size)
        card.position = CGPoint(x: bounds.midX, y: bounds.midY)

        let heartbeat = CABasicAnimation(keyPath: "transform.scale")
        heartbeat.fromValue = 1.0
        heartbeat.toValue = 1.05
        heartbeat.duration = 0.55
        heartbeat.autoreverses = true
        heartbeat.repeatCount = .infinity
        heartbeat.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        card.add(heartbeat, forKey: "heartbeat")
        return card
    }

    private func pulse(from: CGFloat, to: CGFloat) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = 0.55
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    private static func cardImage(sender: String) -> NSImage {
        let title = NSAttributedString(string: "🚨  SOS von \(sender)", attributes: [
            .font: NSFont.systemFont(ofSize: 52, weight: .heavy),
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1)
        ])
        let hint = NSAttributedString(string: "Klicken oder ESC drücken", attributes: [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.35, alpha: 1)
        ])

        let titleSize = title.size()
        let hintSize = hint.size()
        let insetX: CGFloat = 56
        let insetY: CGFloat = 38
        let gap: CGFloat = 16
        let boxWidth = max(titleSize.width, hintSize.width) + insetX * 2
        let boxHeight = titleSize.height + gap + hintSize.height + insetY * 2
        let pad: CGFloat = 20

        return NSImage(size: NSSize(width: boxWidth + pad * 2, height: boxHeight + pad * 2),
                       flipped: false) { _ in
            let box = NSRect(x: pad, y: pad, width: boxWidth, height: boxHeight)

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.45)
            shadow.shadowBlurRadius = 18
            shadow.shadowOffset = NSSize(width: 0, height: -4)
            shadow.set()
            let path = NSBezierPath(roundedRect: box, xRadius: 26, yRadius: 26)
            NSColor(calibratedWhite: 1, alpha: 0.97).setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()

            title.draw(at: NSPoint(x: box.midX - titleSize.width / 2,
                                   y: box.minY + insetY + hintSize.height + gap))
            hint.draw(at: NSPoint(x: box.midX - hintSize.width / 2, y: box.minY + insetY))
            return true
        }
    }
}
