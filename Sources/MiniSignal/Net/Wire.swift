import Foundation
import CryptoKit

/// Eine Sendung zwischen den beiden Macs.
struct Envelope: Codable {
    enum Kind: String, Codable {
        case message   // Nachricht, die ein Bote überbringt
        case sos       // rot blinkender Alarm
        case ack       // "angekommen"
        case seen      // "SOS gesehen"
    }

    var v: Int = 1
    var id: UUID = UUID()
    var kind: Kind
    var text: String = ""
    var sender: String
    var carrier: String? = nil
    var sentAt: Double = Date().timeIntervalSince1970
}

/// Verschlüsselung und Rahmung der Sendungen.
///
/// Statt TLS-PSK (dessen API sich zwischen SDK-Versionen ändert) verschlüsselt
/// MiniSignal jede Sendung direkt mit AES-GCM. Der Schlüssel wird aus dem Paar-Code
/// abgeleitet, den beide Macs teilen — wer den Code nicht hat, dessen Frames lassen
/// sich nicht entschlüsseln und werden verworfen. Das schützt Inhalt und Absender.
enum Wire {

    enum Failure: Error {
        case notPaired
        case badFrame
        case tooOld
    }

    /// Verwirft Sendungen, deren Zeitstempel zu weit weg liegt (Replay-Schutz).
    static let maxAge: TimeInterval = 120

    static func key(fromPairingCode code: String) -> SymmetricKey {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let material = SymmetricKey(data: Data(normalized.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: material,
            salt: Data("MiniSignal.v1.salt".utf8),
            info: Data("pairing".utf8),
            outputByteCount: 32
        )
    }

    static func seal(_ envelope: Envelope, code: String) throws -> Data {
        guard !code.isEmpty else { throw Failure.notPaired }
        let plain = try JSONEncoder().encode(envelope)
        let sealed = try AES.GCM.seal(plain, using: key(fromPairingCode: code))
        guard let combined = sealed.combined else { throw Failure.badFrame }
        return frame(combined)
    }

    static func open(_ payload: Data, code: String) throws -> Envelope {
        guard !code.isEmpty else { throw Failure.notPaired }
        let box = try AES.GCM.SealedBox(combined: payload)
        let plain = try AES.GCM.open(box, using: key(fromPairingCode: code))
        let envelope = try JSONDecoder().decode(Envelope.self, from: plain)
        guard abs(Date().timeIntervalSince1970 - envelope.sentAt) < maxAge else {
            throw Failure.tooOld
        }
        return envelope
    }

    // MARK: - Rahmung: 4 Byte Länge (big endian) + Nutzlast

    static let maxFrameSize = 64 * 1024

    static func frame(_ payload: Data) -> Data {
        var out = Data(capacity: payload.count + 4)
        var length = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    /// Schneidet so viele vollständige Frames wie möglich aus dem Puffer.
    static func drainFrames(from buffer: inout Data) throws -> [Data] {
        var frames: [Data] = []
        while buffer.count >= 4 {
            let length = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length <= UInt32(maxFrameSize) else { throw Failure.badFrame }
            let total = Int(length) + 4
            guard buffer.count >= total else { break }
            frames.append(buffer.subdata(in: 4..<total))
            buffer.removeSubrange(0..<total)
        }
        return frames
    }

    /// DNS-SD-TXT-Record aus Schlüssel/Wert-Paaren.
    static func txtRecordData(_ pairs: [String: String]) -> Data {
        var out = Data()
        for (key, value) in pairs.sorted(by: { $0.key < $1.key }) {
            let entry = Array("\(key)=\(value)".utf8.prefix(255))
            out.append(UInt8(entry.count))
            out.append(contentsOf: entry)
        }
        return out
    }
}
