import AVKit
import UniformTypeIdentifiers

final class ExportSession {
    let session: AVAssetExportSession
    
    var outputURL: URL? = nil
    var outputFileType: AVFileType = .mp4
    
    init?(asset: AVAsset, quality: QualityType?) {
        let session = AVAssetExportSession(
            asset: asset,
            presetName: quality.assetExportSessionPreset
        )
        guard let session else { return nil }
        self.session = session
    }
    
    func export() -> AsyncThrowingStream<Float, any Error> {
        do {
            try setOutputURLIfNeeded()
            try? FileManager.default.removeItem(at: outputURL!)
            session.outputURL = outputURL
            session.outputFileType = outputFileType
            return session.exportProgress()
        } catch {
            return AsyncThrowingStream<Float, any Error>(unfolding: {
                throw error
            })
        }
    }
    
    func setOutputURLIfNeeded() throws {
        guard outputURL == nil else { return }
        let itemReplacementDirectory = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
        let filename = UUID().uuidString
        let outputURL = itemReplacementDirectory
            .appending(path: filename)
            .appendingPathExtension(for: outputFileType.utType ?? UTType.mpeg4Movie)
        self.outputURL = outputURL
    }
}

extension AVFileType {
    fileprivate var utType: UTType? {
        UTType(rawValue)
    }
}
