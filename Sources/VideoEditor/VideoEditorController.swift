import UIKit

@MainActor
public protocol VideoEditorControllerDelegate: AnyObject {
    func videoEditorController(_ editor: VideoEditorController, didSaveEditedVideoToPath editedVideoPath: String, editedRange: CMTimeRange)
    func videoEditorController(_ editor: VideoEditorController, didFailWithError error: any Error)
    func videoEditorControllerDidCancel(_ editor: VideoEditorController)
}

public final class VideoEditorController: UINavigationController {
    public var videoPath: String = ""
    public var videoMaximumDuration: TimeInterval = 600
    public var videoQuality: UIImagePickerController.QualityType = .typeMedium
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
            videoQuality: makeVideoQuality(),
            videoMaximumDuration: makeMaxDuration()
        )
        setViewControllers([vc], animated: false)
    }
    
    func makeVideoQuality() -> String {
        switch videoQuality {
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
        default:
            return AVAssetExportPresetPassthrough
        }
    }
    
    func makeMaxDuration() -> CMTime {
        CMTime(seconds: videoMaximumDuration, preferredTimescale: 600)
    }
}

import Combine

final class EditVideoViewController: UIViewController {
    
    let playerView = PlayerView()
    let trimmer = VideoTrimmer()
    let playbackButton = UIBarButtonItem(image: nil)
    var cancellables: Set<AnyCancellable> = []
    
    private var wasPlaying = false
    let player: AVPlayer = AVPlayer()
    let asset: AVAsset
    let videoQualityPresetName: String
    let maxDuration: CMTime
    
    let exportStatusStackView = UIStackView()
    let exportProgressView = UIProgressView(progressViewStyle: .bar)
    let exportStatusLabel = UILabel()
    
    var videoEditor: VideoEditorController { navigationController as! VideoEditorController }
    
    init(videoURL: URL, videoQuality: String, videoMaximumDuration: CMTime) {
        asset = AVURLAsset(
            url: videoURL,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )
        videoQualityPresetName = videoQuality
        maxDuration = videoMaximumDuration
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Input
    @objc private func didBeginTrimming(_ sender: VideoTrimmer) {
        wasPlaying = (player.timeControlStatus != .paused)
        player.pause()
        
        Task {
            try await updatePlayerAsset()
        }
    }
    
    @objc private func didEndTrimming(_ sender: VideoTrimmer) {
        if wasPlaying == true {
            player.play()
        }
        
        Task {
            try await updatePlayerAsset()
        }
    }
    
    @objc private func selectedRangeDidChanged(_ sender: VideoTrimmer) {
    }
    
    @objc private func didBeginScrubbing(_ sender: VideoTrimmer) {
        wasPlaying = (player.timeControlStatus != .paused)
        player.pause()
    }
    
    @objc private func didEndScrubbing(_ sender: VideoTrimmer) {
        if wasPlaying == true {
            player.play()
        }
    }
    
    @objc private func progressDidChanged(_ sender: VideoTrimmer) {
        let time = CMTimeSubtract(trimmer.progress, trimmer.selectedRange.start)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: - Private
    
    @PlayerAssetActor
    private func updatePlayerAsset() async throws {
        let outputRange = try await trimmer.trimmingState == .none ? trimmer.selectedRange : asset.fullRange
        let trimmedAsset = try await asset.trimmedComposition(outputRange)
        if trimmedAsset != player.currentItem?.asset {
            player.replaceCurrentItem(with: AVPlayerItem(asset: trimmedAsset))
        }
    }
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: String(localized: "Cancel", bundle: .main),
            primaryAction: UIAction { [unowned self] _ in
                exportTask?.cancel()
                videoEditor.editorDelegate?.videoEditorControllerDidCancel(videoEditor)
            }
        )
        navigationItem.title = String(localized: "Edit Video", bundle: .main)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String(localized: "Save", bundle: .main),
            primaryAction: UIAction { [unowned self] _ in
                startExport()
            }
        )
        
        setToolbarItems([
            .flexibleSpace(),
            playbackButton,
            .flexibleSpace(),
        ], animated: false)
        
        playbackButton.primaryAction = UIAction { [unowned self] _ in
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] status in
                let image = status == .playing ? UIImage(systemName: "pause.fill") : UIImage(systemName: "play.fill")
                playbackButton.image = image
            }
            .store(in: &cancellables)
        
        
        playerView.playerLayer.player = player
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
        ])
        
        
        // THIS IS WHERE WE SETUP THE VIDEOTRIMMER:
        trimmer.isHidden = true
        trimmer.minimumDuration = CMTime(seconds: 1, preferredTimescale: 600)
        trimmer.maxDuration = maxDuration
        trimmer.addTarget(self, action: #selector(didBeginTrimming(_:)), for: VideoTrimmer.didBeginTrimming)
        trimmer.addTarget(self, action: #selector(didEndTrimming(_:)), for: VideoTrimmer.didEndTrimming)
        trimmer.addTarget(self, action: #selector(selectedRangeDidChanged(_:)), for: VideoTrimmer.selectedRangeChanged)
        trimmer.addTarget(self, action: #selector(didBeginScrubbing(_:)), for: VideoTrimmer.didBeginScrubbing)
        trimmer.addTarget(self, action: #selector(didEndScrubbing(_:)), for: VideoTrimmer.didEndScrubbing)
        trimmer.addTarget(self, action: #selector(progressDidChanged(_:)), for: VideoTrimmer.progressChanged)
        view.addSubview(trimmer)
        trimmer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trimmer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            trimmer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            trimmer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            trimmer.heightAnchor.constraint(equalToConstant: 44),
        ])
        
        exportProgressView.progress = 0.0
        exportStatusLabel.text = String(localized: "Trimming Video…", bundle: .main)
        exportStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        exportStatusLabel.textAlignment = .center
        
        exportStatusStackView.isHidden = true
        exportStatusStackView.alignment = .fill
        exportStatusStackView.axis = .vertical
        exportStatusStackView.spacing = UIStackView.spacingUseSystem
        view.addSubview(exportStatusStackView)
        exportStatusStackView.addArrangedSubview(exportProgressView)
        exportStatusStackView.addArrangedSubview(exportStatusLabel)
        exportStatusStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.safeAreaLayoutGuide.bottomAnchor.constraint(
                equalTo: exportStatusStackView.bottomAnchor
            ),
            exportStatusStackView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor
            ),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(
                equalTo: exportStatusStackView.trailingAnchor
            ),
        ])
        
        Task {
            try await trimmer.setupAsset(asset)
            if let initialSelectedRange = videoEditor.initialSelectedRange {
                trimmer.selectedRange = initialSelectedRange
            }
            trimmer.isHidden = false
            try await updatePlayerAsset()
        }
        
        player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main,
            using: { [weak self] time in
                guard let self else { return }
                // when we're not trimming, the players starting point is actual later than the trimmer,
                // (because the vidoe has been trimmed), so we need to account for that.
                // When we're trimming, we always show the full video
                let finalTime = self.trimmer.trimmingState == .none ? CMTimeAdd(time, self.trimmer.selectedRange.start) : time
                self.trimmer.progress = finalTime
            }
        )
    }
    
    var exportTask: Task<Void, any Error>? = nil
    var exportProgressCancellable: AnyCancellable? = nil
    
    func startExport() {
        guard let asset = player.currentItem?.asset else { return }
        let session = AVAssetExportSession(
            asset: asset,
            presetName: videoQualityPresetName
        )
        guard let session else { return }
        
        let tempDirectory = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let outputURL = tempDirectory.appending(path: "test.mov")
        try? FileManager.default.removeItem(at: outputURL)
        session.outputURL = outputURL
        session.outputFileType = .mp4
        
        exportProgressCancellable = session.publisher(for: \.error).compactMap({ $0 }).sink { error in
            print("error", error)
        }
        
        exportTask = Task {
            exportStatusStackView.isHidden = false
            
            async let exported: () = withTaskCancellationHandler {
                if session.status != .cancelled {
                    await session.export()
                }
            } onCancel: {
                session.cancelExport()
            }
            
            while [.waiting, .exporting, .unknown].contains(session.status) && session.error == nil {
                print(session.progress)
                exportProgressView.progress = session.progress
                try await Task.sleep(for: .milliseconds(250))
            }
            
            _ = await exported
            
            switch session.status {
            case .unknown:
                print("unknown")
            case .waiting:
                print("waiting")
            case .exporting:
                print("exporting")
            case .completed:
                videoEditor.editorDelegate?.videoEditorController(
                    videoEditor,
                    didSaveEditedVideoToPath: outputURL.path(),
                    editedRange: trimmer.selectedRange
                )
            case .failed:
                if let error = session.error {
                    videoEditor.editorDelegate?.videoEditorController(videoEditor, didFailWithError: error)
                }
            case .cancelled:
                print("cancelled")
            @unknown default:
                print("default")
            }
            
            exportStatusStackView.isHidden = true
        }
    }
}

final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@globalActor
struct PlayerAssetActor {
    actor ActorType { }
    
    static let shared: ActorType = ActorType()
}

import AVKit

extension AVAsset {
    var fullRange: CMTimeRange {
        get async throws {
            let duration = try await load(.duration)
            return CMTimeRange(start: .zero, duration: duration)
        }
    }
    
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
