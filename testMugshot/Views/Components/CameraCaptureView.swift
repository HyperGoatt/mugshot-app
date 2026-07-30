import AVFoundation
import SwiftUI
import UIKit

enum MugshotCameraCompanionPhase: Equatable {
    case opening
    case ready
    case focusing
    case flipping
    case countdown(Int)
    case capturing
    case captured
    case recovering
    case permissionDenied
    case failed
}

struct CameraCaptureView: View {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var camera = MugshotCameraController()
    @State private var showsCompanion = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.phase == .permissionDenied {
                permissionState
            } else if camera.phase == .failed {
                failureState
            } else {
                MugshotCameraPreview(
                    session: camera.session,
                    onFocus: camera.focus,
                    onPinch: camera.adjustZoom(by:)
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.50), .clear, Color.black.opacity(0.66)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                cameraChrome
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            camera.onPhoto = { capturedImage in
                image = capturedImage
                MugshotHaptic.success.play()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 360))
                    isPresented = false
                }
            }
            camera.start()
        }
        .onDisappear {
            camera.stop()
            camera.onPhoto = nil
        }
        .accessibilityIdentifier("mugshot.camera")
    }

    private var cameraChrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                cameraButton(icon: "xmark", label: "Close camera") {
                    isPresented = false
                }

                Spacer()

                cameraButton(icon: camera.timerSeconds == 0 ? "timer" : "timer.circle.fill", label: timerLabel) {
                    camera.cycleTimer()
                    MugshotHaptic.selection.play()
                }

                cameraButton(icon: flashIcon, label: "Flash \(camera.flashMode.accessibilityName)") {
                    camera.cycleFlash()
                    MugshotHaptic.selection.play()
                }

                cameraButton(icon: "arrow.triangle.2.circlepath.camera", label: "Switch camera") {
                    camera.flip()
                    MugshotHaptic.softImpact.play()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            if showsCompanion {
                HStack {
                    MugshotCameraCompanionView(
                        phase: camera.phase,
                        zoom: camera.zoom,
                        exposure: camera.exposure,
                        focusPoint: camera.focusPoint,
                        isFrontCamera: camera.position == .front,
                        flashIsEnabled: camera.flashMode != .off,
                        isPaused: reduceMotion
                    )
                    .frame(width: 76, height: 92)
                    .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 14) {
                cameraAdjustment(
                    icon: "sun.min.fill",
                    label: "Exposure",
                    value: Binding(
                        get: { Double(camera.exposure) },
                        set: { camera.setExposure(Float($0)) }
                    ),
                    range: -2...2,
                    valueLabel: camera.exposure == 0 ? "Auto" : String(format: "%+.1f", camera.exposure)
                )

                cameraAdjustment(
                    icon: "plus.magnifyingglass",
                    label: "Zoom",
                    value: Binding(
                        get: { Double(camera.zoom) },
                        set: { camera.setZoom(CGFloat($0)) }
                    ),
                    range: 1...Double(max(1, min(camera.maxZoom, 5))),
                    valueLabel: String(format: "%.1fx", camera.zoom)
                )

                HStack(alignment: .center) {
                    Button {
                        withAnimation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion)) {
                            showsCompanion.toggle()
                        }
                    } label: {
                        Label(showsCompanion ? "Hide Mugsy" : "Show Mugsy", systemImage: "mug.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color.black.opacity(0.34), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: camera.capture) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 5)
                                .frame(width: 74, height: 74)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                                .scaleEffect(camera.phase == .capturing ? 0.86 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!camera.canCapture)
                    .opacity(camera.canCapture ? 1 : 0.52)
                    .accessibilityLabel(camera.timerSeconds == 0 ? "Take photo" : "Take photo with \(camera.timerSeconds) second timer")

                    Spacer()

                    Text(camera.statusLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 78, alignment: .trailing)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
        }
    }

    private func cameraAdjustment(
        icon: String,
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueLabel: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 20)
            Slider(value: value, in: range)
                .tint(.white)
            Text(valueLabel)
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color.black.opacity(0.34), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func cameraButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.36), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var permissionState: some View {
        VStack(spacing: 18) {
            MugshotCameraCompanionView(phase: .permissionDenied, zoom: 1, exposure: 0)
                .frame(width: 132, height: 154)
            Text("Camera access is off")
                .mugshotDisplay(size: 30)
                .foregroundColor(.white)
            Text("You can allow Camera access in Settings or close this view and choose a photo from your library.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.76))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mugshotSage)
            Button("Close") { isPresented = false }
                .foregroundColor(.white)
        }
    }

    private var failureState: some View {
        VStack(spacing: 18) {
            MugshotCameraCompanionView(phase: .failed, zoom: 1, exposure: 0)
                .frame(width: 132, height: 154)
            Text("The camera needs a moment")
                .mugshotDisplay(size: 30)
                .foregroundColor(.white)
            Text("Nothing about your photo caused this. Try the camera again or choose from your library.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.76))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button("Try Again") { camera.start() }
                .buttonStyle(.borderedProminent)
                .tint(.mugshotSage)
            Button("Close") { isPresented = false }
                .foregroundColor(.white)
        }
    }

    private var flashIcon: String {
        switch camera.flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    private var timerLabel: String {
        camera.timerSeconds == 0 ? "Timer off" : "Timer \(camera.timerSeconds) seconds"
    }
}

struct MugshotCameraCompanionView: View {
    let phase: MugshotCameraCompanionPhase
    let zoom: CGFloat
    let exposure: Float
    var focusPoint: UnitPoint = .center
    var isFrontCamera = false
    var flashIsEnabled = false
    var isPaused = false

    private var action: MugsyActionState {
        switch phase {
        case .opening: return .entering
        case .ready: return .resting
        case .focusing, .countdown: return .focusing
        case .flipping, .capturing: return .capturing
        case .captured: return .success
        case .recovering, .permissionDenied, .failed: return .recovering
        }
    }

    private var gaze: UnitPoint {
        switch phase {
        case .focusing: return focusPoint
        case .flipping: return isFrontCamera ? .trailing : .leading
        default: return .center
        }
    }

    private var configuration: MugsyModelConfiguration {
        var configuration = MugsyPlacement.camera.configuration
        configuration.gaze = gaze
        configuration.pose = zoom > 1.5 ? .leaningRight : .neutral
        configuration.liquid = .coffee(
            fillProgress: 0.7,
            steamIntensity: phase == .captured
                ? 0.82
                : (flashIsEnabled ? 0.38 : 0.24 + CGFloat(abs(exposure)) * 0.08)
        )
        return configuration
    }

    var body: some View {
        MugsyAnimatedView(
            configuration: configuration,
            action: action,
            isPaused: isPaused
        )
        .overlay(alignment: .topTrailing) {
            if flashIsEnabled {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "F3C273"))
                    .padding(6)
                    .background(Color.espressoBrown.opacity(0.82), in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(companionLabel)
    }

    private var companionLabel: String {
        switch phase {
        case .opening: return "Mugsy is joining the camera"
        case .ready: return "Camera ready"
        case .focusing: return "Focus requested"
        case .flipping: return "Switching cameras"
        case .countdown(let count): return "Photo in \(count)"
        case .capturing: return "Taking photo"
        case .captured: return "Photo captured"
        case .recovering: return "Camera is recovering"
        case .permissionDenied: return "Camera permission is off"
        case .failed: return "Camera is unavailable"
        }
    }
}

final class MugshotCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    @Published private(set) var phase: MugshotCameraCompanionPhase = .opening
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published private(set) var flashMode: AVCaptureDevice.FlashMode = .off
    @Published private(set) var zoom: CGFloat = 1
    @Published private(set) var maxZoom: CGFloat = 5
    @Published private(set) var exposure: Float = 0
    @Published private(set) var focusPoint: UnitPoint = .center
    @Published private(set) var timerSeconds = 0

    var onPhoto: ((UIImage) -> Void)?

    private let sessionQueue = DispatchQueue(label: "co.mugshot.camera.session", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var countdownTask: Task<Void, Never>?

    var canCapture: Bool {
        phase == .ready || phase == .focusing
    }

    var statusLabel: String {
        switch phase {
        case .opening: return "Opening"
        case .ready: return "Ready"
        case .focusing: return "Focusing"
        case .flipping: return "Switching"
        case .countdown(let count): return "\(count)"
        case .capturing: return "Capturing"
        case .captured: return "Saved"
        case .recovering: return "Resetting"
        case .permissionDenied: return "Access off"
        case .failed: return "Unavailable"
        }
    }

    func start() {
        countdownTask?.cancel()
        phase = .opening
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.configureAndStart() : self.setPhase(.permissionDenied)
                }
            }
        case .denied, .restricted:
            phase = .permissionDenied
        @unknown default:
            phase = .failed
        }
    }

    func stop() {
        countdownTask?.cancel()
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capture() {
        guard canCapture else { return }
        Task { @MainActor in MugshotHaptic.softImpact.play() }
        if timerSeconds > 0 {
            beginCountdown()
        } else {
            captureNow()
        }
    }

    func flip() {
        guard phase == .ready || phase == .focusing else { return }
        phase = .flipping
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = Self.camera(position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: device) else {
                self?.setPhase(.recoveringThenReady)
                return
            }

            self.session.beginConfiguration()
            let oldInput = self.videoInput
            if let oldInput { self.session.removeInput(oldInput) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoInput = newInput
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.position = newPosition
                    self.zoom = 1
                    self.exposure = 0
                    self.maxZoom = min(device.activeFormat.videoMaxZoomFactor, 8)
                    self.phase = .ready
                }
            } else {
                if let oldInput, self.session.canAddInput(oldInput) {
                    self.session.addInput(oldInput)
                }
                self.session.commitConfiguration()
                self.setPhase(.recoveringThenReady)
            }
        }
    }

    func focus(devicePoint: CGPoint) {
        guard phase == .ready || phase == .focusing else { return }
        focusPoint = UnitPoint(
            x: devicePoint.x.mugshotClamped(to: 0...1),
            y: devicePoint.y.mugshotClamped(to: 0...1)
        )
        phase = .focusing
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    if self.phase == .focusing { self.phase = .ready }
                }
            } catch {
                self.setPhase(.recoveringThenReady)
            }
        }
    }

    func setZoom(_ value: CGFloat) {
        let requested = value.mugshotClamped(to: 1...max(1, maxZoom))
        zoom = requested
        sessionQueue.async { [weak self] in
            guard let device = self?.videoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = requested.mugshotClamped(to: 1...device.activeFormat.videoMaxZoomFactor)
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func adjustZoom(by scale: CGFloat) {
        setZoom(zoom * scale)
    }

    func setExposure(_ value: Float) {
        let requested = value.mugshotClamped(to: -2...2)
        exposure = requested
        sessionQueue.async { [weak self] in
            guard let device = self?.videoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(
                    requested.mugshotClamped(to: device.minExposureTargetBias...device.maxExposureTargetBias),
                    completionHandler: nil
                )
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func cycleFlash() {
        switch flashMode {
        case .off: flashMode = .auto
        case .auto: flashMode = .on
        case .on: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    func cycleTimer() {
        switch timerSeconds {
        case 0: timerSeconds = 3
        case 3: timerSeconds = 10
        default: timerSeconds = 0
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: data) else {
            setPhase(.recoveringThenReady)
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.phase = .captured
            self.onPhoto?(capturedImage)
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                guard self.configureSession() else {
                    self.setPhase(.failed)
                    return
                }
            }
            guard !self.session.isRunning else {
                self.setPhase(.ready)
                return
            }
            self.session.startRunning()
            self.setPhase(.ready)
        }
    }

    private func configureSession() -> Bool {
        guard let device = Self.camera(position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }

        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { return false }
        session.addInput(input)
        session.addOutput(photoOutput)
        videoInput = input
        isConfigured = true
        DispatchQueue.main.async { [weak self] in
            self?.maxZoom = min(device.activeFormat.videoMaxZoomFactor, 8)
        }
        return true
    }

    private func beginCountdown() {
        countdownTask?.cancel()
        let seconds = timerSeconds
        countdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for count in stride(from: seconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self.phase = .countdown(count)
                MugshotHaptic.selection.play()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            self.captureNow()
        }
    }

    private func captureNow() {
        phase = .capturing
        let settings = AVCapturePhotoSettings()
        if videoInput?.device.hasFlash == true,
           photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func setPhase(_ requested: InternalPhase) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch requested {
            case .ready:
                self.phase = .ready
            case .failed:
                self.phase = .failed
            case .permissionDenied:
                self.phase = .permissionDenied
            case .recoveringThenReady:
                self.phase = .recovering
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    if self.phase == .recovering { self.phase = .ready }
                }
            }
        }
    }

    private enum InternalPhase {
        case ready
        case failed
        case permissionDenied
        case recoveringThenReady
    }

    private static func camera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        ).devices.first
    }
}

private struct MugshotCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onFocus: (CGPoint) -> Void
    let onPinch: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFocus: onFocus, onPinch: onPinch)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinched(_:)))
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pinch)
        context.coordinator.previewView = view
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onFocus = onFocus
        context.coordinator.onPinch = onPinch
    }

    final class Coordinator: NSObject {
        var onFocus: (CGPoint) -> Void
        var onPinch: (CGFloat) -> Void
        weak var previewView: PreviewView?

        init(onFocus: @escaping (CGPoint) -> Void, onPinch: @escaping (CGFloat) -> Void) {
            self.onFocus = onFocus
            self.onPinch = onPinch
        }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view = previewView else { return }
            let point = recognizer.location(in: view)
            view.showFocus(at: point)
            onFocus(view.previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }

        @objc func pinched(_ recognizer: UIPinchGestureRecognizer) {
            guard recognizer.state == .changed else { return }
            onPinch(recognizer.scale)
            recognizer.scale = 1
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        func showFocus(at point: CGPoint) {
            let ring = CAShapeLayer()
            ring.path = UIBezierPath(ovalIn: CGRect(x: point.x - 28, y: point.y - 28, width: 56, height: 56)).cgPath
            ring.fillColor = UIColor.clear.cgColor
            ring.strokeColor = UIColor.white.withAlphaComponent(0.88).cgColor
            ring.lineWidth = 1.5
            layer.addSublayer(ring)
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 1.25
            animation.toValue = 0.82
            animation.duration = 0.28
            ring.add(animation, forKey: "focus")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { ring.removeFromSuperlayer() }
        }
    }
}

private extension AVCaptureDevice.FlashMode {
    var accessibilityName: String {
        switch self {
        case .off: return "off"
        case .on: return "on"
        case .auto: return "automatic"
        @unknown default: return "off"
        }
    }
}

#Preview("Camera companion states") {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 28) {
            MugshotCameraCompanionView(phase: .ready, zoom: 1, exposure: 0)
            MugshotCameraCompanionView(phase: .captured, zoom: 2.4, exposure: 0.5)
        }
        .frame(height: 180)
        .padding()
    }
}
