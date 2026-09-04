import AppKit

/// Randloses, transparentes Fenster über allen Spaces und Vollbild-Apps.
/// Standardmäßig mausdurchlässig — der Desktop bleibt ganz normal bedienbar.
final class OverlayWindow: NSWindow {

    private let interactive: Bool
    private let fixedFrame: NSRect?

    /// Ohne `frame` spannt das Fenster über alle Bildschirme; mit `frame` bleibt es
    /// genau auf einem — das ist beim SOS wichtig, damit kein Rahmen im Leeren hängt.
    init(interactive: Bool = false, frame: NSRect? = nil) {
        self.interactive = interactive
        self.fixedFrame = frame
        super.init(
            contentRect: frame ?? OverlayWindow.spanningFrame(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = !interactive
        level = .screenSaver
        // Kein .fullScreenAuxiliary: damit würde macOS das Fenster als Begleiter eines
        // Vollbild-Fensters ansehen und in Mission Control ein eigenes Space dafür anlegen.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none

        let root = NSView(frame: NSRect(origin: .zero, size: self.frame.size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = root
    }

    /// macOS rückt Fenster sonst zurecht, damit sie auf "ihren" Bildschirm passen.
    /// Für ein Overlay, das genau auf einem bestimmten Schirm sitzen soll, wäre das
    /// eine stille Verschiebung — also übernehmen wir den Rahmen unverändert.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { false }

    var stage: CALayer {
        contentView!.layer!
    }

    /// Der Bildschirm, an dem gerade gearbeitet wird — in Koordinaten dieses Fensters.
    var activeScreenRect: CGRect {
        let origin = frame.origin
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return CGRect(origin: .zero, size: frame.size) }
        return screen.frame.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    /// Alle Bildschirme einzeln, in Koordinaten dieses Fensters.
    var screenRects: [CGRect] {
        let origin = frame.origin
        return NSScreen.screens.map { $0.frame.offsetBy(dx: -origin.x, dy: -origin.y) }
    }

    /// Der Bildschirm, auf dem gerade der Mauszeiger steht — die beste Vermutung
    /// darüber, wohin die Person gerade schaut.
    static func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) { return hit }
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Rechteck, das alle angeschlossenen Bildschirme umschließt.
    static func spanningFrame() -> NSRect {
        let screens = NSScreen.screens
        guard var union = screens.first?.frame else {
            return NSRect(x: 0, y: 0, width: 1440, height: 900)
        }
        for screen in screens.dropFirst() { union = union.union(screen.frame) }
        return union
    }

    func present() {
        if fixedFrame == nil {
            setFrame(OverlayWindow.spanningFrame(), display: false)
        }
        contentView?.frame = NSRect(origin: .zero, size: frame.size)
        orderFrontRegardless()
    }
}
