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
