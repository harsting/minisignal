import AppKit

/// Rendert Emoji und Nachrichten-Banner einmalig in Bilder, die dann als
/// Layer-Inhalt animiert werden. Kein Neuzeichnen während der Animation.
enum Artwork {

    static let ink = NSColor(calibratedWhite: 0.10, alpha: 1.0)
    static let senderInk = NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.72, alpha: 1.0)
    static let bubbleFill = NSColor(calibratedWhite: 1.0, alpha: 0.97)
    static let bannerFill = NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.87, alpha: 0.98)
    static let bannerEdge = NSColor(calibratedRed: 0.88, green: 0.29, blue: 0.28, alpha: 1.0)

    /// Abstand der Sprechblasen-Spitze vom linken Bildrand — die Animation richtet
    /// die Blase daran aus, damit die Spitze genau auf das Tier zeigt.
    static let bubbleTailInset: CGFloat = 62

    /// Auf großen Bildschirmen wachsen Tiere und Schilder mit, damit sie nicht verloren wirken.
    static var displayScale: CGFloat {
        let height = NSScreen.main?.frame.height ?? 900
        return min(max(height / 900, 1.0), 1.7)
    }

    // MARK: - Sprite

    static func sprite(for art: CarrierArt, size: CGFloat) -> NSImage {
        switch art {
        case .emoji(let emoji):
            return emojiImage(emoji, pointSize: size * displayScale)
        case .image(let name):
            let url = Bundle.main.resourceURL?
                .appendingPathComponent("Carriers")
                .appendingPathComponent(name)
            if let url, let img = NSImage(contentsOf: url) { return img }
            return emojiImage("❓", pointSize: size)
        }
    }

    static func emojiImage(_ emoji: String, pointSize: CGFloat) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: pointSize)
        ]
        let string = NSAttributedString(string: emoji, attributes: attrs)
        let measured = string.size()
        let pad = pointSize * 0.18
        let size = NSSize(width: ceil(measured.width + pad * 2),
                          height: ceil(measured.height + pad * 2))

        return NSImage(size: size, flipped: false) { _ in
            string.draw(at: NSPoint(x: pad, y: pad))
            return true
        }
    }

    // MARK: - Banner

    /// Sprechblase bzw. Schild mit der Nachricht.
    static func banner(text: String, sender: String, style: BannerStyle) -> NSImage {
        let scale = displayScale
        switch style {
        case .towed:
            return towedBanner(text: text, sender: sender, fontSize: 26 * scale)
        case .onBack, .slung:
            return bubble(text: text, sender: sender, maxWidth: 300 * scale, fontSize: 17 * scale, tail: false)
        case .bubbleAbove:
            return bubble(text: text, sender: sender, maxWidth: 380 * scale, fontSize: 19 * scale, tail: true)
        }
    }

    private static func bubble(text: String, sender: String, maxWidth: CGFloat,
                               fontSize: CGFloat, tail: Bool) -> NSImage {
        let senderAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize * 0.68, weight: .semibold),
            .foregroundColor: senderInk
        ]
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineBreakMode = .byWordWrapping
        bodyStyle.lineSpacing = 2
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: ink,
            .paragraphStyle: bodyStyle
        ]

        let senderString = NSAttributedString(string: sender.uppercased(), attributes: senderAttrs)
        let bodyString = NSAttributedString(string: text, attributes: bodyAttrs)

        let inset: CGFloat = 16
        let textWidth = maxWidth - inset * 2
        let bodyRect = bodyString.boundingRect(
            with: NSSize(width: textWidth, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let senderRect = senderString.boundingRect(
            with: NSSize(width: textWidth, height: 100),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let bodyHeight = ceil(bodyRect.height) + 4
        let senderHeight = ceil(senderRect.height) + 2
        let contentWidth = min(textWidth, ceil(max(bodyRect.width, senderRect.width)) + 2)
        let gap: CGFloat = 5
        let tailHeight: CGFloat = tail ? 12 : 0
        let boxWidth = contentWidth + inset * 2
        let boxHeight = senderHeight + gap + bodyHeight + inset * 2

        let shadowPad: CGFloat = 14
        let imageSize = NSSize(width: boxWidth + shadowPad * 2,
                               height: boxHeight + tailHeight + shadowPad * 2)

        return NSImage(size: imageSize, flipped: false) { _ in
            let box = NSRect(x: shadowPad, y: shadowPad + tailHeight,
                             width: boxWidth, height: boxHeight)

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.35)
            shadow.shadowBlurRadius = 12
            shadow.shadowOffset = NSSize(width: 0, height: -3)
            shadow.set()

            let path = NSBezierPath(roundedRect: box, xRadius: 18, yRadius: 18)
            if tail {
                let tipX = box.minX + 46
                let tri = NSBezierPath()
                tri.move(to: NSPoint(x: tipX - 13, y: box.minY + 2))
                tri.line(to: NSPoint(x: tipX + 3, y: box.minY - tailHeight))
                tri.line(to: NSPoint(x: tipX + 17, y: box.minY + 2))
                tri.close()
                path.append(tri)
            }
            bubbleFill.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSColor(calibratedWhite: 0, alpha: 0.10).setStroke()
            path.lineWidth = 1
            path.stroke()

            let bodyOrigin = NSPoint(x: box.minX + inset, y: box.minY + inset)
            bodyString.draw(with: NSRect(origin: bodyOrigin,
                                         size: NSSize(width: contentWidth, height: bodyHeight)),
                            options: [.usesLineFragmentOrigin, .usesFontLeading])
            let senderOrigin = NSPoint(x: box.minX + inset,
                                       y: box.minY + inset + bodyHeight + gap)
            senderString.draw(with: NSRect(origin: senderOrigin,
                                           size: NSSize(width: contentWidth, height: senderHeight)),
                              options: [.usesLineFragmentOrigin, .usesFontLeading])
            return true
        }
    }

    /// Langes Stoffbanner hinter dem Flugzeug — einzeilig.
    private static func towedBanner(text: String, sender: String, fontSize: CGFloat) -> NSImage {
        let line = "\(sender): \(text)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: ink
        ]
        let string = NSAttributedString(string: line, attributes: attrs)
        let measured = string.size()

        let insetX: CGFloat = fontSize
        let insetY: CGFloat = fontSize * 0.46
        let boxWidth = ceil(measured.width) + 2 + insetX * 2
        let boxHeight = ceil(measured.height) + 4 + insetY * 2
        let shadowPad: CGFloat = 12
        let imageSize = NSSize(width: boxWidth + shadowPad * 2, height: boxHeight + shadowPad * 2)

        return NSImage(size: imageSize, flipped: false) { _ in
            let box = NSRect(x: shadowPad, y: shadowPad, width: boxWidth, height: boxHeight)

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.3)
            shadow.shadowBlurRadius = 10
            shadow.shadowOffset = NSSize(width: 0, height: -3)
            shadow.set()
            let path = NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6)
            bannerFill.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()

            bannerEdge.setFill()
            NSRect(x: box.minX, y: box.minY, width: box.width, height: 4).fill()
            NSRect(x: box.minX, y: box.maxY - 4, width: box.width, height: 4).fill()

            string.draw(at: NSPoint(x: box.minX + insetX, y: box.minY + insetY))
            return true
        }
    }
}
