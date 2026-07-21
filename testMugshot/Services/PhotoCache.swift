//
//  PhotoCache.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import UIKit

enum PhotoCacheError: LocalizedError, Equatable {
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .jpegEncodingFailed:
            return "Mugshot could not prepare this photo for durable storage."
        }
    }
}

final class PhotoCache: @unchecked Sendable {
    static let shared = PhotoCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "com.mugshot.photocache", attributes: .concurrent)
    private let fileManager: FileManager
    private let photosDirectory: URL

    init(
        fileManager: FileManager = .default,
        photosDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.photosDirectory = photosDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("VisitPhotos", isDirectory: true)
        cache.totalCostLimit = 32 * 1_024 * 1_024
        cache.countLimit = 40
    }
    
    // Store image both in memory and on disk
    func store(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            // Store in memory cache
            self.cache.setObject(image, forKey: key as NSString, cost: image.memoryCost)

            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            try? self.persistJPEGData(imageData, forKey: key)
        }
    }

    /// Persists a JPEG atomically before returning.
    ///
    /// Recovery-sensitive save paths can call this method before committing a
    /// visit that references the key. The existing `store` API remains the
    /// best-effort asynchronous option for non-blocking legacy paths.
    func storeDurably(_ image: UIImage, forKey key: String) throws {
        try queue.sync(flags: .barrier) {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw PhotoCacheError.jpegEncodingFailed
            }
            try persistJPEGData(imageData, forKey: key)
            cache.setObject(image, forKey: key as NSString, cost: image.memoryCost)
        }
    }
    
    // Retrieve image from memory cache or disk
    func retrieve(forKey key: String) -> UIImage? {
        return queue.sync {
            // First check memory cache
            if let cachedImage = cache.object(forKey: key as NSString) {
                return cachedImage
            }
            
            // If not in memory, try to load from disk
            let fileURL = photoFileURL(forKey: key)
            
            if fileManager.fileExists(atPath: fileURL.path),
               let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                // Store in memory cache for future access
                cache.setObject(image, forKey: key as NSString, cost: image.memoryCost)
                return image
            }
            
            return nil
        }
    }

    func image(forKey key: String) async -> UIImage? {
        if let cached = cache.object(forKey: key as NSString) { return cached }
        let fileURL = photoFileURL(forKey: key)
        guard let image = await Task.detached(priority: .utility, operation: {
            UIImage(contentsOfFile: fileURL.path)
        }).value else { return nil }
        cache.setObject(image, forKey: key as NSString, cost: image.memoryCost)
        return image
    }
    
    // Clear memory cache (disk files remain)
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
    
    // Preload images for visits when app starts
    func preloadImages(for photoPaths: [String]) {
        queue.async {
            for path in photoPaths {
                // Load from disk if not in memory
                let fileURL = self.photoFileURL(forKey: path)
                
                if self.fileManager.fileExists(atPath: fileURL.path),
                   let imageData = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: imageData) {
                    // Store in memory cache
                    self.cache.setObject(image, forKey: path as NSString, cost: image.memoryCost)
                }
            }
        }
    }

    private func persistJPEGData(_ imageData: Data, forKey key: String) throws {
        try fileManager.createDirectory(
            at: photosDirectory,
            withIntermediateDirectories: true
        )
        try imageData.write(to: photoFileURL(forKey: key), options: .atomic)
    }

    private func photoFileURL(forKey key: String) -> URL {
        photosDirectory.appendingPathComponent("\(key).jpg")
    }
}

private extension UIImage {
    var memoryCost: Int {
        cgImage.map { $0.bytesPerRow * $0.height } ?? Int(size.width * size.height * 4)
    }
}
