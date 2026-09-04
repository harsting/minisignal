import Foundation
import Network

/// Findet den anderen Mac im WLAN (Bonjour) und tauscht verschlüsselte Sendungen aus.
/// Beide Geräte sind gleichberechtigt: jedes lauscht und jedes sucht.
final class PeerService {

    static let serviceType = "_minisignal._tcp"

    enum Presence: Equatable {
        case notPaired
        case searching
        case online(name: String)
        case offline
    }

    enum SendError: LocalizedError {
        case notPaired
        case noPeer
        case timeout
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .notPaired: return "Noch kein Paar-Code eingerichtet"
            case .noPeer:    return "Niemand da — läuft MiniSignal auf dem anderen Mac?"
            case .timeout:   return "Keine Antwort — der andere Mac schläft vermutlich"
            case .transport(let detail): return detail
            }
        }
    }

    /// Callbacks kommen immer auf dem Main-Thread.
    var onEnvelope: ((Envelope) -> Void)?
    var onPresence: ((Presence) -> Void)?

    private let queue = DispatchQueue(label: "de.21dx.minisignal.net")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var inbound: [ObjectIdentifier: FramedConnection] = [:]
    private var outbound: [ObjectIdentifier: FramedConnection] = [:]
    private var peerEndpoint: NWEndpoint?
    private var peerName: String?

    private(set) var presence: Presence = .searching {
        didSet {
            guard presence != oldValue else { return }
            let value = presence
            DispatchQueue.main.async { [weak self] in self?.onPresence?(value) }
        }
    }

    var peerDisplayName: String { peerName ?? "Der andere Mac" }

    // MARK: - Lebenszyklus

    func start() {
        stop()
        guard Settings.shared.isConfigured else {
            presence = .notPaired
            return
        }
        presence = .searching
        startListener()
        startBrowser()

        // Wenn nach einer Weile niemand geantwortet hat, ehrlich sein statt ewig "suche …".
        queue.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.presence == .searching else { return }
            self.presence = .offline
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
        peerEndpoint = nil
        peerName = nil
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
                    "name": Settings.shared.displayName
                ])
            )
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                NSLog("MiniSignal: Listener-Status = \(state)")
                if case .failed = state { self?.presence = .offline }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            NSLog("MiniSignal: Listener konnte nicht starten: \(error)")
            presence = .offline
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
            NSLog("MiniSignal: Browser-Treffer = \(results.count) -> \(results.map { "\($0.endpoint)" })")
            self?.updatePeer(from: results)
        }
        browser.stateUpdateHandler = { [weak self] state in
            NSLog("MiniSignal: Browser-Status = \(state)")
            if case .failed = state { self?.presence = .offline }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    private func serviceName() -> String {
        let short = String(Settings.shared.instanceID.prefix(4))
        return "\(Settings.shared.displayName) \(short)"
    }

    private func updatePeer(from results: Set<NWBrowser.Result>) {
        let mine = Settings.shared.instanceID

        for result in results {
            guard case .bonjour(let txt) = result.metadata else { continue }
            guard txt["id"] != mine else { continue }
            peerEndpoint = result.endpoint
            peerName = txt["name"] ?? "Der andere Mac"
            presence = .online(name: peerName ?? "")
            return
        }

        peerEndpoint = nil
        presence = .offline
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

    func send(_ envelope: Envelope, completion: @escaping (Result<Void, SendError>) -> Void) {
        let code = Settings.shared.pairingCode
        guard !code.isEmpty else { return finish(completion, .failure(.notPaired)) }
        guard let endpoint = peerEndpoint else { return finish(completion, .failure(.noPeer)) }
        guard let payload = try? Wire.seal(envelope, code: code) else {
            return finish(completion, .failure(.transport("Nachricht ließ sich nicht verpacken")))
        }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = false
        let framed = FramedConnection(NWConnection(to: endpoint, using: parameters), queue: queue)
        let key = ObjectIdentifier(framed)

        var settled = false
        let settle: (Result<Void, SendError>) -> Void = { [weak self, weak framed] result in
            guard !settled else { return }
            settled = true
            framed?.cancel()
            self?.queue.async { self?.outbound[key] = nil }
            self?.finish(completion, result)
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

    /// Für Quittungen, bei denen keine Antwort erwartet wird.
    func sendQuietly(_ envelope: Envelope) {
        send(envelope) { _ in }
    }

    private func finish(_ completion: @escaping (Result<Void, SendError>) -> Void,
                        _ result: Result<Void, SendError>) {
        DispatchQueue.main.async { completion(result) }
    }
}
