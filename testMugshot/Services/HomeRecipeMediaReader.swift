import AVFoundation
import CoreTransferable
import Foundation
import Speech
import UniformTypeIdentifiers
import UIKit
@preconcurrency import Vision

struct HomeRecipeMovie: Transferable, Sendable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let size = try received.file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 50_000_000 else { throw HomeRecipeSourceError.tooLarge }
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return HomeRecipeMovie(url: copy)
        }
    }
}

struct HomeRecipeVideoCapture {
    let text: String
    let image: UIImage
    let frameCount: Int
    let hasTranscript: Bool
}

final class HomeRecipeMediaReader: @unchecked Sendable {
    func text(in image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw HomeRecipeSourceError.invalidMedia }
        let orientation: CGImagePropertyOrientation
        switch image.imageOrientation {
        case .up: orientation = .up
        case .down: orientation = .down
        case .left: orientation = .left
        case .right: orientation = .right
        case .upMirrored: orientation = .upMirrored
        case .downMirrored: orientation = .downMirrored
        case .leftMirrored: orientation = .leftMirrored
        case .rightMirrored: orientation = .rightMirrored
        @unknown default: orientation = .up
        }
        let text: String = try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request])
                    let observations = (request.results ?? []).sorted {
                        if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.02 { return $0.boundingBox.midY > $1.boundingBox.midY }
                        return $0.boundingBox.minX < $1.boundingBox.minX
                    }
                    continuation.resume(returning: observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"))
                } catch { continuation.resume(throwing: error) }
            }
        }
        try Task.checkCancellation()
        return String(text.prefix(12_000))
    }

    @MainActor
    func video(at url: URL, includeSpeech: Bool = false) async throws -> HomeRecipeVideoCapture {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw HomeRecipeSourceError.invalidMedia }
        guard duration <= 60.5 else { throw HomeRecipeSourceError.videoTooLong }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        defer { generator.cancelAllCGImageGeneration() }
        var frames: [UIImage] = [], recognized: [String] = []
        let count = min(6, max(1, Int(duration.rounded(.up))))
        for index in 0..<count {
            try Task.checkCancellation()
            let seconds = min(max(0, duration - 0.15), (Double(index) + 0.25) * duration / Double(count))
            let frame = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            let image = UIImage(cgImage: frame.image)
            frames.append(image)
            if let words = try? await text(in: image), !words.isEmpty { recognized.append("Frame \(index + 1):\n\(words)") }
        }
        var transcript: String?
        if includeSpeech, !(try await asset.loadTracks(withMediaType: .audio)).isEmpty {
            transcript = try? await HomeRecipeSpeechReader().read(url)
        }
        try Task.checkCancellation()
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: CGFloat((frames.count + 1) / 2) * 600)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: CGFloat((frames.count + 1) / 2) * 600))
            for (index, image) in frames.enumerated() {
                let cell = CGRect(x: CGFloat(index % 2) * 600, y: CGFloat(index / 2) * 600, width: 600, height: 600)
                let scale = min(560 / image.size.width, 550 / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: CGRect(x: cell.midX - size.width / 2, y: cell.midY - size.height / 2, width: size.width, height: size.height))
                "Frame \(index + 1)".draw(at: CGPoint(x: cell.minX + 20, y: cell.maxY - 28), withAttributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.black])
            }
        }
        if let transcript, !transcript.isEmpty { recognized.append("Spoken instructions (on-device transcript):\n\(transcript)") }
        return HomeRecipeVideoCapture(text: String(recognized.joined(separator: "\n\n").prefix(12_000)), image: sheet,
                                      frameCount: frames.count, hasTranscript: transcript?.isEmpty == false)
    }
}

@MainActor
private final class HomeRecipeSpeechReader {
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    func read(_ url: URL) async throws -> String {
        try Task.checkCancellation()
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        try Task.checkCancellation()
        guard authorization == .authorized, let recognizer = SFSpeechRecognizer(), recognizer.supportsOnDeviceRecognition else {
            throw HomeRecipeSourceError.unavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    Task { @MainActor in
                        if let error { self?.finish(.failure(error)) }
                        else if let result, result.isFinal { self?.finish(.success(result.bestTranscription.formattedString)) }
                    }
                }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(25))
                    self?.finish(.failure(HomeRecipeSourceError.unavailable))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }
    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        task?.cancel(); task = nil
        continuation.resume(with: result)
    }
}
