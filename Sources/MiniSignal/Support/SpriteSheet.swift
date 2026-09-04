import AppKit

/// Entwicklerhilfe: rendert alle Boten nebeneinander in eine PNG-Datei,
/// um zu prüfen, ob jedes Tier in seine Laufrichtung schaut.
/// Aufruf: MINISIGNAL_SPRITESHEET=/pfad/blatt.png
enum SpriteSheet {

    /// Freie Emoji-Liste prüfen, bevor daraus Boten werden:
    /// MINISIGNAL_SPRITESHEET_EMOJI="🦥,🐇,🦋"
    static func writeEmoji(_ emoji: [String], to path: String) {
        let cell = NSSize(width: 190, height: 220)
        let columns = min(emoji.count, 8)
        let rows = Int(ceil(Double(emoji.count) / Double(columns)))
        let size = NSSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows))

        let sheet = NSImage(size: size, flipped: false) { _ in
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()
            for (index, glyph) in emoji.enumerated() {
                let column = index % columns
                let row = index / columns
                let x = CGFloat(column) * cell.width
                let y = size.height - CGFloat(row + 1) * cell.height
                let sprite = Artwork.emojiImage(glyph, pointSize: 96)
                sprite.draw(in: NSRect(x: x + (cell.width - sprite.size.width) / 2,
                                       y: y + 60,
                                       width: sprite.size.width, height: sprite.size.height))
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                NSAttributedString(string: glyph, attributes: [
                    .font: NSFont.systemFont(ofSize: 15),
                    .paragraphStyle: style
                ]).draw(in: NSRect(x: x, y: y + 24, width: cell.width, height: 26))
                NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
                NSRect(x: x + cell.width - 1, y: y, width: 1, height: cell.height).fill()
            }
            return true
        }
        save(sheet, to: path)
    }

    static func write(to path: String) {
        let carriers = Carriers.all
        let cell = NSSize(width: 230, height: 280)
        let columns = min(carriers.count, 6)
        let rows = Int(ceil(Double(carriers.count) / Double(columns)))
        let size = NSSize(width: cell.width * CGFloat(columns),
                          height: cell.height * CGFloat(rows))

        let sheet = NSImage(size: size, flipped: false) { _ in
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()

            for (index, carrier) in carriers.enumerated() {
                let x = CGFloat(index % columns) * cell.width
                let y = size.height - CGFloat(index / columns + 1) * cell.height
                let sprite = Artwork.sprite(for: carrier.art, size: 96)
                sprite.draw(in: NSRect(x: x + (cell.width - sprite.size.width) / 2,
                                       y: y + 100,
                                       width: sprite.size.width,
                                       height: sprite.size.height))

                let caption = "\(carrier.id)\nläuft \(carrier.travelsRight ? "nach rechts →" : "← nach links")"
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                NSAttributedString(string: caption, attributes: [
                    .font: NSFont.systemFont(ofSize: 20, weight: .medium),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: style
                ]).draw(in: NSRect(x: x, y: y + 30, width: cell.width, height: 60))

                NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
                NSRect(x: x + cell.width - 1, y: y, width: 1, height: cell.height).fill()
            }
            return true
        }

        save(sheet, to: path)
    }

    private static func save(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
