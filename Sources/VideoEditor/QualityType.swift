import AVKit

public enum QualityType {
    case typeHigh
    case typeMedium
    case typeLow
    case type640x480
    case typeIFrame1280x720
    case typeIFrame960x540
}

extension Optional<QualityType> {
    var assetExportSessionPreset: String {
        switch self {
        case .none:
            return AVAssetExportPresetPassthrough
        case .typeHigh:
            return AVAssetExportPresetHighestQuality
        case .typeMedium:
            return AVAssetExportPresetMediumQuality
        case .typeLow:
            return AVAssetExportPresetLowQuality
        case .type640x480:
            return AVAssetExportPreset640x480
        case .typeIFrame1280x720:
            return AVAssetExportPreset1280x720
        case .typeIFrame960x540:
            return AVAssetExportPreset960x540
        }
    }
}
