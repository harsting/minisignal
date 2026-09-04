import AppKit

/// Entwicklerhilfe: erzeugt das App-Symbol in allen Größen.
/// Aufruf über make_icon.sh, nicht zur Laufzeit nötig.
enum IconMaker {

    /// Schreibt alle für ein .iconset nötigen PNGs in das Verzeichnis.
    static func writeIconset(to directory: String) {
        let variants: [(name: String, pixels: CGFloat)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32),
            ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256),
            ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024)
        ]

        try? FileManager.default.createDirectory(atPath: directory,
                                                 withIntermediateDirectories: true)

        for variant in variants {
            let image = draw(pixels: variant.pixels)
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { continue }
            let url = URL(fileURLWithPath: directory)
                .appendingPathComponent("\(variant.name).png")
            try? png.write(to: url)
        }
    }

    /// Abgerundetes Quadrat im macOS-Zuschnitt, darauf der Liebesbrief.
    static func draw(pixels: CGFloat) -> NSImage {
        let canvas = NSSize(width: pixels, height: pixels)

        return NSImage(size: canvas, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return true }

            // Apple lässt rundherum Luft; das Symbol füllt rund 82 % der Fläche.
            let inset = pixels * 0.09
            let box = NSRect(x: inset, y: inset,
                             width: pixels - inset * 2, height: pixels - inset * 2)
            let radius = box.width * 0.2237   // Zuschnitt der macOS-Symbole
            let shape = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)

            context.saveGState()
            shape.addClip()

            let gradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.36, green: 0.44, blue: 1.00, alpha: 1),
                NSColor(calibratedRed: 0.52, green: 0.32, blue: 0.90, alpha: 1)
            ])
            gradient?.draw(in: box, angle: -90)

            // Weicher Lichtschein oben, damit die Fläche nicht flach wirkt.
            let glow = NSGradient(colors: [
                NSColor(calibratedWhite: 1, alpha: 0.28),
                NSColor(calibratedWhite: 1, alpha: 0.0)
            ])
            glow?.draw(in: NSRect(x: box.minX, y: box.midY,
                                  width: box.width, height: box.height / 2), angle: -90)
            context.restoreGState()

            // Feine helle Kante
            NSColor(calibratedWhite: 1, alpha: 0.35).setStroke()
            shape.lineWidth = max(pixels * 0.006, 0.5)
            shape.stroke()

            let letter = Artwork.emojiImage("💌", pointSize: pixels * 0.52)
            let target = NSRect(x: box.midX - letter.size.width / 2,
                                y: box.midY - letter.size.height / 2,
                                width: letter.size.width, height: letter.size.height)
            letter.draw(in: target)
            return true
        }
    }
}
