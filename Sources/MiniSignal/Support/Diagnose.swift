import AppKit

/// Entwicklerhilfe: zeigt, wie macOS die Bildschirme anordnet und wo das
/// Overlay-Fenster tatsächlich landet. Aufruf: MINISIGNAL_DIAGNOSE=1
enum Diagnose {

    static func run() {
        print("Bildschirme:")
        for (index, screen) in NSScreen.screens.enumerated() {
            let isMain = screen == NSScreen.main ? "  ← NSScreen.main" : ""
            print(String(format: "  [%d] frame  x=%.0f y=%.0f  %.0f × %.0f%@",
                         index, screen.frame.minX, screen.frame.minY,
                         screen.frame.width, screen.frame.height, isMain))
            print(String(format: "      sichtbar y=%.0f  höhe %.0f  (Menüleiste/Dock abgezogen)",
                         screen.visibleFrame.minY, screen.visibleFrame.height))
        }

        guard let screen = OverlayWindow.screenUnderPointer() else {
            print("Kein Bildschirm gefunden.")
            return
        }
        print(String(format: "\nBote läuft auf: x=%.0f y=%.0f  %.0f × %.0f",
                     screen.frame.minX, screen.frame.minY,
                     screen.frame.width, screen.frame.height))

        let window = OverlayWindow(interactive: false, frame: screen.frame)
        window.present()
        let actual = window.frame
        print(String(format: "Overlay-Fenster tatsächlich: x=%.0f y=%.0f  %.0f × %.0f",
                     actual.minX, actual.minY, actual.width, actual.height))
        if abs(actual.height - screen.frame.height) > 1 || abs(actual.minY - screen.frame.minY) > 1 {
            print("  ⚠️  macOS hat das Fenster verschoben oder beschnitten.")
        } else {
            print("  ✓ sitzt genau auf dem Bildschirm")
        }

        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        print("\nBahnhöhen (0 = unterer Rand des Bildschirms):")
        for carrier in Carriers.all {
            let y = bounds.minY + 80 + carrier.lane * max(bounds.height - 210, 100)
            let sprite = carrier.spriteSize * Artwork.displayScale
            let top = y + sprite / 2
            let ok = top <= bounds.height && y >= 0
            print(String(format: "  %-11@ y=%.0f  Oberkante %.0f von %.0f  %@",
                         carrier.id as NSString, y, top, bounds.height,
                         ok ? "✓" : "⚠️  ragt hinaus"))
        }
        window.orderOut(nil)
    }
}
