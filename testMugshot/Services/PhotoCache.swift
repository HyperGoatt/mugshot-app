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
    static let shared = PhotoCache(initialScope: .guest)
    
    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "com.mugshot.photocache", attributes: .concurrent)
    private let fileManager: FileManager
    private let photosDirectory: URL
    private var activeScope: LocalAccountScope?
    private var scopeGeneration: UInt = 0

    init(
        fileManager: FileManager = .default,
        photosDirectory: URL? = nil,
        initialScope: LocalAccountScope? = nil
    ) {
        self.fileManager = fileManager
        self.photosDirectory = photosDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("VisitPhotos", isDirectory: true)
        self.activeScope = initialScope
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
        let lookup = queue.sync {
            (
                generation: scopeGeneration,
                cached: cache.object(forKey: key as NSString),
                fileURL: photoFileURL(forKey: key)
            )
        }
        if let cached = lookup.cached { return cached }
        guard let image = await Task.detached(priority: .utility, operation: {
            UIImage(contentsOfFile: lookup.fileURL.path)
        }).value else { return nil }
        return queue.sync(flags: .barrier) {
            guard scopeGeneration == lookup.generation else { return nil }
            cache.setObject(image, forKey: key as NSString, cost: image.memoryCost)
            return image
        }
    }

    /// Switches the cache boundary synchronously. Known legacy files are
    /// copied into the new account scope, while unreferenced legacy files are
    /// left untouched and inaccessible.
    func activate(
        scope: LocalAccountScope,
        migratingKnownKeys knownKeys: Set<String> = []
    ) throws {
        try queue.sync(flags: .barrier) {
            let targetDirectory = scopedDirectory(for: scope)
            if !knownKeys.isEmpty {
                try fileManager.createDirectory(
                    at: targetDirectory,
                    withIntermediateDirectories: true
                )
                for key in knownKeys {
                    let source = legacyPhotoFileURL(forKey: key)
                    let destination = photoFileURL(forKey: key, directory: targetDirectory)
                    guard fileManager.fileExists(atPath: source.path),
                          !fileManager.fileExists(atPath: destination.path) else { continue }
                    try fileManager.copyItem(at: source, to: destination)
                }
            }

            guard activeScope != scope else { return }
            cache.removeAllObjects()
            activeScope = scope
            scopeGeneration &+= 1
        }
    }
    
    // Clear memory cache (disk files remain)
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }

    /// Removes one account's scoped disk cache and only the legacy photo keys
    /// proven to belong to that account. Guest and other-account caches remain.
    func purge(ownerUserID: UUID, attributableLegacyKeys: Set<String> = []) throws {
        try queue.sync(flags: .barrier) {
            let scope = LocalAccountScope.user(ownerUserID)
            let directory = scopedDirectory(for: scope)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
            for key in attributableLegacyKeys where safeLegacyPhotoKey(key) {
                let legacyURL = legacyPhotoFileURL(forKey: key)
                if fileManager.fileExists(atPath: legacyURL.path) {
                    try fileManager.removeItem(at: legacyURL)
                }
            }
            if activeScope == scope {
                cache.removeAllObjects()
                activeScope = .guest
                scopeGeneration &+= 1
            }
        }
    }

    private func safeLegacyPhotoKey(_ key: String) -> Bool {
        !key.isEmpty
            && key.count <= 240
            && key != "."
            && key != ".."
            && !key.contains("/")
            && !key.contains("\\")
            && !key.contains(":")
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
        let directory = currentPhotosDirectory
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try imageData.write(to: photoFileURL(forKey: key, directory: directory), options: .atomic)
    }

    private func photoFileURL(forKey key: String) -> URL {
        photoFileURL(forKey: key, directory: currentPhotosDirectory)
    }

    private func photoFileURL(forKey key: String, directory: URL) -> URL {
        directory.appendingPathComponent("\(key).jpg")
    }

    private func legacyPhotoFileURL(forKey key: String) -> URL {
        photoFileURL(forKey: key, directory: photosDirectory)
    }

    private var currentPhotosDirectory: URL {
        guard let activeScope else { return photosDirectory }
        return scopedDirectory(for: activeScope)
    }

    private func scopedDirectory(for scope: LocalAccountScope) -> URL {
        let v2Directory = photosDirectory.appendingPathComponent("v2", isDirectory: true)
        switch scope {
        case .guest:
            return v2Directory.appendingPathComponent("guest", isDirectory: true)
        case .user(let userID):
            return v2Directory
                .appendingPathComponent("users", isDirectory: true)
                .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: true)
        }
    }
}

private extension UIImage {
    var memoryCost: Int {
        cgImage.map { $0.bytesPerRow * $0.height } ?? Int(size.width * size.height * 4)
    }
}
