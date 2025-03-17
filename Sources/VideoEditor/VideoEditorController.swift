import UIKit
import AVFoundation
import AVFoundationBackport_iOS17

@MainActor
public protocol VideoEditorControllerDelegate: AnyObject {
    func videoEditorController(_ editor: VideoEditorController, didSaveEditedVideoToPath editedVideoPath: String, editedRange: CMTimeRange)
    func videoEditorController(_ editor: VideoEditorController, didFailWithError error: any Error)
    func videoEditorControllerDidCancel(_ editor: VideoEditorController)
}

public final class VideoEditorController: UINavigationController {
    public var videoPath: String = ""
    public var videoMaximumDuration: TimeInterval = 600
    
    public var videoQuality: QualityType? = .typeMedium
    public var initialSelectedRange: CMTimeRange? = nil
    public weak var editorDelegate: (any VideoEditorControllerDelegate)? = nil
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        isToolbarHidden = false
        
        let videoURL = URL(filePath: videoPath)
        let vc = EditVideoViewController(
            videoURL: videoURL,
            videoQuality: videoQuality,
            videoMaximumDuration: makeMaxDuration()
        )
        setViewControllers([vc], animated: false)
    }
    
    func makeMaxDuration() -> CMTime {
        CMTime(seconds: videoMaximumDuration, preferredTimescale: 600)
    }
}

