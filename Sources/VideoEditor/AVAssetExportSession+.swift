import AVKit

extension AVAssetExportSession {
    func exportProgress() -> AsyncThrowingStream<Float, any Error> {
        AsyncThrowingStream<Float, any Error> { [unowned self] continuation in
            let timerCanceller = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect().sink { _ in
                continuation.yield(progress)
            }
            exportAsynchronously {
                timerCanceller.cancel()
                switch status {
                case .cancelled:
                    continuation.finish(throwing: CancellationError())
                default:
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [unowned self] termination in
                switch termination {
                case .cancelled:
                    cancelExport()
                case .finished:
                    break
                }
            }
        }
    }
}
