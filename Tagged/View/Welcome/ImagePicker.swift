import SwiftUI
import PhotosUI

// MARK: - ImagePicker: UIViewControllerRepresentable

/// A wrapper for PHPickerViewController to allow SwiftUI image selection.
struct ImagePicker: UIViewControllerRepresentable {
    
    // MARK: - Bindings
    
    @Binding var selectedImage: UIImage?
    @Binding var showPhotoError: Bool

    // MARK: - Make PHPickerViewController
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No update logic needed
    }

    // MARK: - Coordinator
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator Class

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                        self.parent.showPhotoError = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.parent.showPhotoError = true
                }
            }
        }
    }
}
