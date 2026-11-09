import AVFoundation
import CoreVideo
import Testing
import UIKit
@testable import testMugshot

@MainActor
struct HomeRecipeVideoTests {
    @Test func anActualVideoYieldsFramesWithoutClaimingUnheardSpokenSteps() async throws {
        let url = try await movie(seconds: 2)
        defer { try? FileManager.default.removeItem(at: url) }
        let capture = try await HomeRecipeMediaReader().video(at: url)
        #expect(capture.frameCount == 2)
        #expect(capture.image.size.width == 1200)
        #expect(!capture.text.contains("on-device transcript"))
    }

    @Test func aLongVideoHasAnExplicitFallbackBeforeAnyFramesOrSpeechAreRead() async throws {
        let url = try await movie(seconds: 62)
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: HomeRecipeSourceError.videoTooLong) {
            try await HomeRecipeMediaReader().video(at: url)
        }
    }

    private func movie(seconds: Double) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 640, AVVideoHeightKey: 480
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 640, kCVPixelBufferHeightKey as String: 480
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? HomeRecipeSourceError.invalidMedia }
        writer.startSession(atSourceTime: .zero)
        for time in [0.0, seconds - 0.1] {
            for _ in 0..<500 where !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(10)) }
            guard input.isReadyForMoreMediaData else { throw HomeRecipeSourceError.invalidMedia }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 640, 480, kCVPixelFormatType_32ARGB,
                [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer)
            let frame = try #require(buffer)
            CVPixelBufferLockBaseAddress(frame, [])
            let context = try #require(CGContext(data: CVPixelBufferGetBaseAddress(frame), width: 640, height: 480,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(frame), space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue))
            context.setFillColor(UIColor.white.cgColor); context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).image { _ in
                "Ingredients:\n2 g matcha\nSteps:\nWhisk with water.".draw(in: CGRect(x: 30, y: 30, width: 580, height: 400),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 38), .foregroundColor: UIColor.black])
            }
            context.draw(try #require(image.cgImage), in: CGRect(x: 0, y: 0, width: 640, height: 480))
            CVPixelBufferUnlockBaseAddress(frame, [])
            guard adaptor.append(frame, withPresentationTime: CMTime(seconds: time, preferredTimescale: 600)) else {
                throw writer.error ?? HomeRecipeSourceError.invalidMedia
            }
        }
        input.markAsFinished(); writer.endSession(atSourceTime: CMTime(seconds: seconds, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? HomeRecipeSourceError.invalidMedia }
        return url
    }
}
