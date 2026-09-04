import Foundation
import Network

/// Dünne Hülle um NWConnection, die den Byte-Strom in vollständige Frames zerlegt.
final class FramedConnection {

    private let connection: NWConnection
    private let queue: DispatchQueue
    private var buffer = Data()
    private var isClosed = false

    var onReady: (() -> Void)?
    var onFrame: ((Data) -> Void)?
    var onClose: ((Error?) -> Void)?

    init(_ connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.onReady?()
            case .failed(let error):
                self.close(error)
            case .cancelled:
                self.close(nil)
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveNext()
    }

    func send(_ payload: Data) {
        connection.send(content: payload, completion: .contentProcessed { [weak self] error in
            if let error { self?.close(error) }
        })
    }

    func cancel() {
        guard !isClosed else { return }
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Wire.maxFrameSize) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.buffer.append(data)
                do {
                    for frame in try Wire.drainFrames(from: &self.buffer) {
                        self.onFrame?(frame)
                    }
                } catch {
                    self.close(error)
                    self.connection.cancel()
                    return
                }
            }

            if let error {
                self.close(error)
                return
            }
            if isComplete {
                self.close(nil)
                self.connection.cancel()
                return
            }
            self.receiveNext()
        }
    }

    private func close(_ error: Error?) {
        guard !isClosed else { return }
        isClosed = true
        onClose?(error)
    }
}
