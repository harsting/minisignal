import Foundation
import Network

/// Findet alle anderen Geräte mit demselben Paar-Code im WLAN und tauscht
/// verschlüsselte Sendungen aus. Alle Geräte sind gleichberechtigt:
/// jedes lauscht, jedes sucht.
final class PeerService {

    static let serviceType = "_minisignal._tcp"

    struct Peer: Equatable, Hashable {
        let id: String
        let name: String
        let endpoint: NWEndpoint

        static func == (a: Peer, b: Peer) -> Bool { a.id == b.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    enum SendError: LocalizedError {
        case notPaired
        case noPeer
        case timeout
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .notPaired: return "Noch kein Paar-Code eingerichtet"
            case .noPeer:    return "Niemand da — läuft MiniSignal auf dem anderen Gerät?"
            case .timeout:   return "keine Antwort"
            case .transport(let detail): return detail
            }
        }
    }

    /// Ergebnis eines Versands an mehrere Empfänger.
    struct SendReport {
        var delivered: [String] = []
        var failed: [(name: String, error: SendError)] = []

        var allFailed: Bool { delivered.isEmpty && !failed.isEmpty }
        var summary: String {
            if delivered.isEmpty && failed.isEmpty { return "Niemand da" }
            var parts: [String] = []
            if !delivered.isEmpty {
                parts.append("Angekommen bei \(PeerService.list(delivered)) ✓")
            }
            for failure in failed {
                parts.append("\(failure.name): \(failure.error.localizedDescription)")
            }
            return parts.joined(separator: " · ")
        }
    }

    /// Callbacks kommen immer auf dem Main-Thread.
    var onEnvelope: ((Envelope) -> Void)?
    /// Wird bei jeder Änderung der Anwesenheit gerufen; `searching` heißt: noch am Suchen.
    var onPeersChanged: (([Peer], Bool) -> Void)?

    private let queue = DispatchQueue(label: "de.21dx.minisignal.net")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var inbound: [ObjectIdentifier: FramedConnection] = [:]
    private var outbound: [ObjectIdentifier: FramedConnection] = [:]

    private(set) var peers: [Peer] = []
    private var isSearching = true

    // MARK: - Lebenszyklus

    func start() {
        stop()
        guard Settings.shared.isConfigured else {
            isSearching = false
            publishPeers()
            return
        }
        isSearching = true
        publishPeers()
        startListener()
        startBrowser()

        // Nach einer Weile ehrlich sein statt ewig "suche …".
        queue.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.isSearching else { return }
            self.isSearching = false
            self.publishPeers()
        }
    }

    func stop() {
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
        queue.async { [weak self] in
            self?.inbound.values.forEach { $0.cancel() }
            self?.outbound.values.forEach { $0.cancel() }
            self?.inbound.removeAll()
            self?.outbound.removeAll()
        }
        peers = []
    }

    /// Nach Änderung von Name oder Paar-Code neu anmelden.
    func restart() { start() }

    private func startListener() {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = false
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(
                name: serviceName(),
                type: PeerService.serviceType,
                domain: nil,
                txtRecord: Wire.txtRecordData([
                    "id": Settings.shared.instanceID,
                    "name": Settings.shared.displayName,
                    "fp": Wire.fingerprint(forCode: Settings.shared.pairingCode)
                ])
            )
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            NSLog("MiniSignal: Listener konnte nicht starten: \(error)")
        }
    }

    private func startBrowser() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = false

        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: PeerService.serviceType, domain: nil),
            using: parameters
        )
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.updatePeers(from: results)
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    private func serviceName() -> String {
        let short = String(Settings.shared.instanceID.prefix(4))
        return "\(Settings.shared.displayName) \(short)"
    }

    private func updatePeers(from results: Set<NWBrowser.Result>) {
        let mine = Settings.shared.instanceID
        let myFingerprint = Wire.fingerprint(forCode: Settings.shared.pairingCode)
        var found: [Peer] = []

        for result in results {
            guard case .bonjour(let txt) = result.metadata else { continue }
            guard let id = txt["id"], id != mine else { continue }
            // Nur Geräte mit demselben Paar-Code zählen als anwesend — sonst würden
            // fremde Haushalte im selben WLAN als erreichbar erscheinen.
            guard txt["fp"] == myFingerprint else { continue }
            found.append(Peer(id: id,
                              name: txt["name"] ?? "Unbekanntes Gerät",
                              endpoint: result.endpoint))
        }

        peers = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isSearching = false
        publishPeers()
    }

    private func publishPeers() {
        let snapshot = peers
        let searching = isSearching
        DispatchQueue.main.async { [weak self] in
            self?.onPeersChanged?(snapshot, searching)
        }
    }

    func peer(withID id: String?) -> Peer? {
        guard let id else { return nil }
        return peers.first { $0.id == id }
    }

    // MARK: - Empfangen

    private func accept(_ connection: NWConnection) {
        let framed = FramedConnection(connection, queue: queue)
        let key = ObjectIdentifier(framed)
        inbound[key] = framed

        framed.onFrame = { [weak self, weak framed] payload in
            guard let self else { return }
            guard let envelope = try? Wire.open(payload, code: Settings.shared.pairingCode) else {
                framed?.cancel()   // fremder Absender oder falscher Paar-Code
                return
            }

            if envelope.kind == .message || envelope.kind == .sos {
                let ack = Envelope(kind: .ack, sender: Settings.shared.displayName)
                if let data = try? Wire.seal(ack, code: Settings.shared.pairingCode) {
                    framed?.send(data)
                }
            }

            DispatchQueue.main.async { self.onEnvelope?(envelope) }
        }
        framed.onClose = { [weak self] _ in
            self?.queue.async { self?.inbound[key] = nil }
        }
        framed.start()
    }

    // MARK: - Senden

    /// Schickt an die angegebenen Empfänger; leere Liste heißt: an alle.
    func send(_ envelope: Envelope, to recipients: [Peer] = [],
              completion: @escaping (SendReport) -> Void) {
        let targets = recipients.isEmpty ? peers : recipients

        guard !Settings.shared.pairingCode.isEmpty else {
            return finish(completion, SendReport(delivered: [], failed: [("", .notPaired)]))
        }
        guard !targets.isEmpty else {
            return finish(completion, SendReport())
        }

        var report = SendReport()
        let group = DispatchGroup()
        let lock = NSLock()

        for target in targets {
            group.enter()
            sendOne(envelope, to: target) { result in
                lock.lock()
                switch result {
                case .success: report.delivered.append(target.name)
                case .failure(let error): report.failed.append((target.name, error))
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { completion(report) }
    }

    /// Für Quittungen, bei denen keine Rückmeldung gebraucht wird.
    func sendQuietly(_ envelope: Envelope, to peer: Peer?) {
        guard let peer else { return }
        send(envelope, to: [peer]) { _ in }
    }

    private func sendOne(_ envelope: Envelope, to target: Peer,
                         completion: @escaping (Result<Void, SendError>) -> Void) {
        let code = Settings.shared.pairingCode
        guard let payload = try? Wire.seal(envelope, code: code) else {
            return completion(.failure(.transport("Nachricht ließ sich nicht verpacken")))
        }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = false
        let framed = FramedConnection(NWConnection(to: target.endpoint, using: parameters),
                                      queue: queue)
        let key = ObjectIdentifier(framed)

        var settled = false
        let settle: (Result<Void, SendError>) -> Void = { [weak self, weak framed] result in
            guard !settled else { return }
            settled = true
            framed?.cancel()
            self?.queue.async { self?.outbound[key] = nil }
            completion(result)
        }

        queue.async { [weak self] in self?.outbound[key] = framed }

        framed.onReady = { [weak framed] in framed?.send(payload) }
        framed.onFrame = { data in
            if let reply = try? Wire.open(data, code: code), reply.kind == .ack {
                settle(.success(()))
            }
        }
        framed.onClose = { error in
            settle(.failure(error.map { .transport($0.localizedDescription) } ?? .timeout))
        }
        framed.start()

        queue.asyncAfter(deadline: .now() + 4) { settle(.failure(.timeout)) }
    }

    private func finish(_ completion: @escaping (SendReport) -> Void, _ report: SendReport) {
        DispatchQueue.main.async { completion(report) }
    }

    /// "Anna", "Anna und Lena", "Anna, Lena und Tom"
    static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        default:
            return names.dropLast().joined(separator: ", ") + " und " + names[names.count - 1]
        }
    }
}
