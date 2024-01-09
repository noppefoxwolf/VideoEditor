import SwiftUI
import VideoEditor

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
        
        button.addAction(UIAction { _ in
            self.present()
        }, for: .primaryActionTriggered)
    }
    
    
    func present() {
        let vc = VideoEditorController()
        vc.videoPath = Bundle.main.url(forResource: "file_example_MP4_640_3MG", withExtension: "mp4")!.path()
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
    }
    
    func videoEditorController(_ editor: VideoEditorController, didFailWithError error: any Error) {
        editor.dismiss(animated: true)
    }
    
    func videoEditorControllerDidCancel(_ editor: VideoEditorController) {
        editor.dismiss(animated: true)
    }
}

