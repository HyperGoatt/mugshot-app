import Foundation
import ImageIO
import UIKit

actor RemoteImagePipeline {
    static let shared = RemoteImagePipeline()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let protectedSession: URLSession
    private var inFlight: [String: Task<UIImage, Error>] = [:]

    init() {
        cache.totalCostLimit = 64 * 1_024 * 1_024
        cache.countLimit = 80

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 256 * 1_024 * 1_024
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
        let protectedConfiguration = URLSessionConfiguration.ephemeral
        protectedConfiguration.urlCache = nil
        protectedConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        protectedSession = URLSession(configuration: protectedConfiguration)
    }

    func image(for url: URL, maxPixelSize: Int = 1_200) async throws -> UIImage {
        // Signed capabilities must not outlive authorization in memory or on disk.
        if url.path.hasPrefix("/storage/v1/object/sign/") {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30
            let (data, response) = try await protectedSession.data(for: request)
            if let response = response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                throw RemoteImagePipelineError.httpStatus(response.statusCode)
            }
            try Task.checkCancellation()
            return try Self.downsample(data: data, maxPixelSize: maxPixelSize)
        }
        let key = "\(url.absoluteString)#\(maxPixelSize)"
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        if let existing = inFlight[key] {
            return try await existing.value
        }

        let session = session
        let task = Task<UIImage, Error> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30
            let (data, response) = try await PerformanceMonitor.measure(
                "Remote image network",
                minimumLogMilliseconds: 50
            ) {
                try await session.data(for: request)
            }
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw RemoteImagePipelineError.httpStatus(httpResponse.statusCode)
            }

            return try await Task.detached(priority: .utility) {
                try Self.downsample(data: data, maxPixelSize: maxPixelSize)
            }.value
        }
        inFlight[key] = task

        do {
            let image = try await task.value
            inFlight[key] = nil
            cache.setObject(
                image,
                forKey: key as NSString,
                cost: image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            )
            return image
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    private nonisolated static func downsample(data: Data, maxPixelSize: Int) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw RemoteImagePipelineError.invalidImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw RemoteImagePipelineError.invalidImage
        }
        return UIImage(cgImage: cgImage)
    }
}

private enum RemoteImagePipelineError: Error {
    case httpStatus(Int)
    case invalidImage
}
