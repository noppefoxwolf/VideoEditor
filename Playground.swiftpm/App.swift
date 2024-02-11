import SwiftUI
import AVKit
import VideoEditor
import PhotosUI

@main
struct App: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        ViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}

import CoreMedia

class ViewController: UIViewController {
    let label: UILabel = UILabel()
    let button: UIButton = UIButton(configuration: .filled())
    var selectedRange: CMTimeRange? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        label.text = "Hello, World!"
        button.configuration?.title = "Button"
        
        let stackView = UIStackView(
            arrangedSubviews: [
                label,
                button
            ]
        )
        stackView.axis = .vertical
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            ),
            stackView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 20
            ),
            view.trailingAnchor.constraint(
                equalTo: stackView.safeAreaLayoutGuide.trailingAnchor,
                constant: 20
            ),
        ])
        
        button.addAction(UIAction { [unowned self] _ in
            presentPicker()
        }, for: .primaryActionTriggered)
    }
    
    func presentPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .videos
        let vc = PHPickerViewController(configuration: configuration)
        vc.delegate = self
        present(vc, animated: true)
    }
    
    func presentEditor(url: URL) {
        let vc = VideoEditorController()
        vc.videoPath = url.path()
        vc.videoQuality = nil
        vc.videoMaximumDuration = 5
        vc.initialSelectedRange = selectedRange
        vc.editorDelegate = self
        present(vc, animated: true)
    }
}

extension ViewController: VideoEditorControllerDelegate {
    func videoEditorController(_ editor: VideoEditorController, didSaveEditedVideoToPath editedVideoPath: String, editedRange: CMTimeRange) {
        editor.dismiss(animated: true)
        self.selectedRange = editedRange
        
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: URL(filePath: editedVideoPath))
        present(vc, animated: true)
    }
    
    func videoEditorController(_ editor: VideoEditorController, didFailWithError error: any Error) {
        editor.dismiss(animated: true)
    }
    
    func videoEditorControllerDidCancel(_ editor: VideoEditorController) {
        editor.dismiss(animated: true)
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        _ = result.itemProvider.loadFileRepresentation(for: .movie) { url, _, error in
            let url = url!
            let tempDirectory = try! FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: url,
                create: true
            )
            let destURL = tempDirectory.appending(path: url.lastPathComponent)
            try? FileManager.default.removeItem(at: destURL)
            try! FileManager.default.moveItem(at: url, to: destURL)
            DispatchQueue.main.async {
                self.presentEditor(url: destURL)
            }
        }
    }
}

