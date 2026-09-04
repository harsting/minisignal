import AppKit

/// Kurze Systemklänge — keine eigenen Audiodateien nötig.
/// Respektiert die Systemlautstärke; ein stummer Mac bleibt stumm.
enum Sounds {

    private static var sosSound: NSSound?
    private static var sosRepeat: Timer?

    private static var enabled: Bool {
        if ProcessInfo.processInfo.environment["MINISIGNAL_MUTE"] != nil { return false }
        return Settings.shared.soundsEnabled
    }

    static func playArrival() {
        guard enabled else { return }
        NSSound(named: "Submarine")?.play()
    }

    static func playSent() {
        guard enabled else { return }
        NSSound(named: "Pop")?.play()
    }

    static func playSOS() {
        guard enabled else { return }
        stopSOS()
        let fire = {
            let sound = NSSound(named: "Sosumi")
            sound?.volume = 1.0
            sound?.play()
            sosSound = sound
        }
        fire()
        sosRepeat = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { _ in fire() }
    }

    static func stopSOS() {
        sosRepeat?.invalidate()
        sosRepeat = nil
        sosSound?.stop()
        sosSound = nil
    }
}
