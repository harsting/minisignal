import Foundation

/// Persistente Einstellungen. Über die Umgebungsvariable MINISIGNAL_SUITE lässt sich
/// eine zweite, unabhängige Instanz auf demselben Mac starten (für Tests).
final class Settings {
    static let shared = Settings()

    private let defaults: UserDefaults

    private init() {
        if let suite = ProcessInfo.processInfo.environment["MINISIGNAL_SUITE"], !suite.isEmpty {
            defaults = UserDefaults(suiteName: "de.21dx.minisignal.\(suite)") ?? .standard
        } else {
            defaults = .standard
        }
    }

    var displayName: String {
        get {
            if let env = ProcessInfo.processInfo.environment["MINISIGNAL_NAME"], !env.isEmpty { return env }
            let stored = defaults.string(forKey: "displayName") ?? ""
            return stored.isEmpty ? (Host.current().localizedName ?? "Mac") : stored
        }
        set { defaults.set(newValue, forKey: "displayName") }
    }

    /// Gemeinsames Geheimnis beider Macs. Leer = noch nicht eingerichtet.
    var pairingCode: String {
        get {
            if let env = ProcessInfo.processInfo.environment["MINISIGNAL_CODE"], !env.isEmpty { return env }
            return defaults.string(forKey: "pairingCode") ?? ""
        }
        set { defaults.set(newValue, forKey: "pairingCode") }
    }

    /// Bevorzugter Bote; nil bedeutet "würfeln".
    var preferredCarrier: String? {
        get { defaults.string(forKey: "preferredCarrier") }
        set { defaults.set(newValue, forKey: "preferredCarrier") }
    }

    // MARK: - Kurzbefehl

    var hotkeyEnabled: Bool {
        get { defaults.object(forKey: "hotkeyEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hotkeyEnabled") }
    }

    /// Virtueller Tastencode (Carbon). Vorgabe: Leertaste.
    var hotkeyKeyCode: UInt32 {
        get { UInt32(defaults.object(forKey: "hotkeyKeyCode") as? Int ?? 49) }
        set { defaults.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    /// Modifier als Carbon-Maske. Vorgabe: ⌃⌥.
    var hotkeyModifiers: UInt32 {
        get { UInt32(defaults.object(forKey: "hotkeyModifiers") as? Int ?? (4096 | 2048)) }
        set { defaults.set(Int(newValue), forKey: "hotkeyModifiers") }
    }

    /// Lesbare Form für die Anzeige, z. B. "⌃⌥Leertaste".
    var hotkeyDisplay: String {
        get { defaults.string(forKey: "hotkeyDisplay") ?? "⌃⌥Leertaste" }
        set { defaults.set(newValue, forKey: "hotkeyDisplay") }
    }

    // MARK: - Einladung

    var repoURL: String {
        get { defaults.string(forKey: "repoURL") ?? "https://github.com/harsting/minisignal" }
        set { defaults.set(newValue, forKey: "repoURL") }
    }

    var downloadURL: String {
        get { defaults.string(forKey: "downloadURL")
                ?? "https://github.com/harsting/minisignal/releases/latest" }
        set { defaults.set(newValue, forKey: "downloadURL") }
    }

    var soundsEnabled: Bool {
        get { defaults.object(forKey: "soundsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "soundsEnabled") }
    }

    /// Stabile, zufällige Kennung dieser Installation — damit die App sich selbst
    /// nicht als Gegenstelle im Bonjour-Browser aufsammelt.
    var instanceID: String {
        if let existing = defaults.string(forKey: "instanceID"), !existing.isEmpty { return existing }
        let fresh = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        defaults.set(fresh, forKey: "instanceID")
        return fresh
    }

    var isConfigured: Bool { !pairingCode.isEmpty }

    // Kleiner Durchgriff für Verlauf & Co.
    func store(_ data: Data?, forKey key: String) { defaults.set(data, forKey: key) }
    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
}
