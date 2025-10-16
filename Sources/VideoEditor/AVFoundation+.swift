import AVKit

extension AVAsset {
    @MainActor
    var fullRange: CMTimeRange {
        get async throws {
            let duration = try await load(.duration)
            return CMTimeRange(start: .zero, duration: duration)
        }
    }
    
    @MainActor
    func trimmedComposition(_ range: CMTimeRange) async throws -> AVAsset {
        let fullRange = try await fullRange
        guard CMTimeRangeEqual(fullRange, range) == false else { return self }
        
        let composition = AVMutableComposition()
        try await composition.insertTimeRange(range, of: self, at: .zero)
        
        if let videoTrack = try await loadTracks(withMediaType: .video).first {
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            composition.tracks.forEach {
                $0.preferredTransform = preferredTransform
            }
        }
        return composition
    }
}
