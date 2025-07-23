import Combine
import UIKit
@preconcurrency import AVFoundation
import os

final class EditVideoViewController: UIViewController {
    
    // MARK: - Properties
    private let playerView = AVPlayerView()
    private let trimmer = VideoTrimmer()
    private let playbackButton = UIBarButtonItem(image: nil)
    private var cancellables: Set<AnyCancellable> = []
    private var wasPlaying = false
    
    private let player: AVPlayer = AVPlayer()
    private let asset: AVAsset
    private let videoQuality: QualityType?
    private let maxDuration: CMTime
    
    private let exportStatusStackView = UIStackView()
    private let exportProgressView = UIProgressView(progressViewStyle: .bar)
    private let exportStatusLabel = UILabel()
    
    private var progressTask: Task<Void, any Error>?
    private var exportTask: Task<Void, any Error>?
    
    private var videoEditor: VideoEditorController {
        navigationController as! VideoEditorController
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: #file
    )
    
    // MARK: - Initialization
    init(videoURL: URL, videoQuality: QualityType?, videoMaximumDuration: CMTime) {
        asset = AVURLAsset(
            url: videoURL,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )
        self.videoQuality = videoQuality
        maxDuration = videoMaximumDuration
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupTrimmer()
        loadAssetAsync()
    }
    
    // MARK: - Private Setup Methods
    private func setupUI() {
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
        
        setupPlayerView()
        setupExportStatusView()
    }
    
    private func setupPlayerView() {
        playerView.playerLayer.player = player
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
        ])
    }
    
    private func setupExportStatusView() {
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
    }
    
    private func setupActions() {
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
        
        player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main,
            using: { [weak self] time in
                Task { [weak self] in
                    await self?.update(time)
                }
            }
        )
    }
    
    private func setupTrimmer() {
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
    }
    
    private func loadAssetAsync() {
        Task {
            do {
                try await trimmer.setupAsset(asset)
                if let initialSelectedRange = videoEditor.initialSelectedRange {
                    trimmer.selectedRange = initialSelectedRange
                }
                trimmer.isHidden = false
                try await updatePlayerAsset()
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Player Update
    @MainActor
    private func update(_ time: CMTime) {
        let finalTime = trimmer.trimmingState == .none ? CMTimeAdd(time, trimmer.selectedRange.start) : time
        trimmer.progress = finalTime
    }
    
    // MARK: - Action Methods
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
    
    // MARK: - Export Methods
    private func startExport() {
        guard let asset = player.currentItem?.asset else { return }
        let session = AVAssetExportSession(
            asset: asset,
            presetName: videoQuality.assetExportSessionPreset
        )
        guard let session else { return }
        
        progressTask = Task {
            for try await state in session.states(updateInterval: 0.25) {
                switch state {
                case .pending, .waiting:
                    break
                case .exporting(let progress):
                    exportProgressView.progress = Float(progress.fractionCompleted)
                }
            }
        }
        
        exportTask = Task {
            exportStatusStackView.isHidden = false
            do {
                let itemReplacementDirectory = try FileManager.default.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: FileManager.default.temporaryDirectory,
                    create: true
                )
                let filename = UUID().uuidString
                let outputURL = itemReplacementDirectory
                    .appending(path: filename)
                    .appendingPathExtension(for: session.outputFileType?.utType ?? UTType.mpeg4Movie)
                try? FileManager.default.removeItem(at: outputURL)
                
                try await session.export(to: outputURL, as: .mp4)
                
                videoEditor.editorDelegate?.videoEditorController(
                    videoEditor,
                    didSaveEditedVideoToPath: session.outputURL!.path(),
                    editedRange: trimmer.selectedRange
                )
            } catch {
                videoEditor.editorDelegate?.videoEditorController(videoEditor, didFailWithError: error)
            }
            exportStatusStackView.isHidden = true
        }
    }
    
    // MARK: - Private Asset Methods
    @PlayerAssetActor
    private func updatePlayerAsset() async throws {
        let outputRange = try await trimmer.trimmingState == .none ? trimmer.selectedRange : asset.fullRange
        let trimmedAsset = try await asset.trimmedComposition(outputRange)
        if await trimmedAsset != player.currentItem?.asset {
            await player.replaceCurrentItem(with: AVPlayerItem(asset: trimmedAsset))
        }
    }
}


@globalActor
struct PlayerAssetActor {
    actor ActorType { }
    
    static let shared: ActorType = ActorType()
}