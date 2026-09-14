import AVFoundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Presents Apple's standard still-photo camera and returns the original image.
///
/// Camera controls intentionally belong to the system picker. Mugshot only owns
/// permission/unavailable states and the handoff back into the existing Add flow.
struct CameraCaptureView: View {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    @State private var availability: NativeCameraAvailability = .checking

    var body: some View {
        Group {
            switch availability {
            case .checking:
                ProgressView("Opening Camera…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .foregroundStyle(.white)
            case .available:
                NativeStillCameraPicker(image: $image, isPresented: $isPresented)
                    .ignoresSafeArea()
            case .permissionDenied:
                CameraUnavailableView(
                    title: "Camera access is off",
                    message: "Allow camera access in Settings, or close this screen and choose a photo from your library.",
                    showsSettingsAction: true,
                    onClose: { isPresented = false }
                )
            case .unavailable:
                CameraUnavailableView(
                    title: "Camera unavailable",
                    message: "Close this screen and choose a photo from your library instead.",
                    showsSettingsAction: false,
                    onClose: { isPresented = false }
                )
            }
        }
        .preferredColorScheme(.dark)
        .task { await resolveAvailability() }
        .accessibilityIdentifier("mugshot.camera")
    }

    @MainActor
    private func resolveAvailability() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            availability = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            availability = .available
        case .notDetermined:
            availability = await AVCaptureDevice.requestAccess(for: .video)
                ? .available
                : .permissionDenied
        case .denied, .restricted:
            availability = .permissionDenied
        @unknown default:
            availability = .permissionDenied
        }
    }
}

private enum NativeCameraAvailability {
    case checking
    case available
    case permissionDenied
    case unavailable
}

private struct NativeStillCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding private var image: UIImage?
        @Binding private var isPresented: Bool
        private var completed = false

        init(image: Binding<UIImage?>, isPresented: Binding<Bool>) {
            _image = image
            _isPresented = isPresented
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard !completed else { return }
            completed = true
            image = info[.originalImage] as? UIImage
            isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard !completed else { return }
            completed = true
            isPresented = false
        }
    }
}

private struct CameraUnavailableView: View {
    let title: String
    let message: String
    let showsSettingsAction: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 42, weight: .semibold))
            Text(title)
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if showsSettingsAction {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Close", action: onClose)
                .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
