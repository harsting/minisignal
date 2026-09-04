import AppKit

/// Entwicklerhilfe für Screenshots: legt eine neutrale Fläche über den Desktop,
/// damit für die Dokumentation nichts Privates mit aufs Bild kommt.
/// Aufruf: MINISIGNAL_DEMO_BACKDROP=1
enum DemoBackdrop {

    private static var window: OverlayWindow?

    static func show() {
        guard let screen = OverlayWindow.screenUnderPointer() else { return }

        let backdrop = OverlayWindow(interactive: false, frame: screen.frame)
        // Knapp unter den Boten, aber über allem anderen.
        backdrop.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        backdrop.isOpaque = true

        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        let stage = backdrop.stage
        stage.frame = bounds

        let sky = CAGradientLayer()
        sky.frame = bounds
        sky.colors = [
            NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.26, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.24, green: 0.29, blue: 0.48, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.55, green: 0.44, blue: 0.52, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.92, green: 0.66, blue: 0.48, alpha: 1).cgColor
        ]
        sky.locations = [0.0, 0.45, 0.78, 1.0]
        sky.startPoint = CGPoint(x: 0.5, y: 1.0)
        sky.endPoint = CGPoint(x: 0.5, y: 0.0)
        stage.addSublayer(sky)

        // Angedeutete Hügel, damit die Fläche nicht wie ein Farbverlauf-Testbild wirkt.
        for (index, height) in [0.20, 0.14, 0.09].enumerated() {
            let hill = CAShapeLayer()
            let path = CGMutablePath()
            let top = bounds.height * height
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: top * 0.7))
            path.addCurve(to: CGPoint(x: bounds.width, y: top * 0.55),
                          control1: CGPoint(x: bounds.width * 0.3, y: top * 1.5),
                          control2: CGPoint(x: bounds.width * 0.7, y: top * 0.1))
            path.addLine(to: CGPoint(x: bounds.width, y: 0))
            path.closeSubpath()
            hill.path = path
            let shade = 0.10 + Double(index) * 0.05
            hill.fillColor = NSColor(calibratedRed: shade, green: shade * 1.1,
                                     blue: shade * 1.4, alpha: 1).cgColor
            stage.addSublayer(hill)
        }

        backdrop.present()
        window = backdrop
    }

    static func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
