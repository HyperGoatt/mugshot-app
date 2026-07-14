//
//  PhotoLibraryPickerView.swift
//  testMugshot
//

import PhotosUI
import SwiftUI
import UIKit

/// A UIKit bridge keeps Camera and Library selection on the same UIImage path.
/// Upload normalization therefore happens once, immediately before storage.
struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Binding var isPresented: Bool
    let maximumSelectionCount: Int

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = maximumSelectionCount

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoLibraryPickerView

        init(parent: PhotoLibraryPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            parent.isPresented = false

            Task {
                var selected: [UIImage] = []
                for result in results {
                    guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                    if let image = await loadImage(from: result.itemProvider) {
                        selected.append(image)
                    }
                }

                await MainActor.run {
                    parent.images = selected
                }
            }
        }

        private func loadImage(from provider: NSItemProvider) async -> UIImage? {
            await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
    }
}
