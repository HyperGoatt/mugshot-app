//
//  PhotoCache.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import UIKit

class PhotoCache {
    static let shared = PhotoCache()
    
    private var cache: [String: UIImage] = [:]
    private var thumbnailCache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.mugshot.photocache", attributes: .concurrent)
    
    /// PERF: Limit concurrent preloads to avoid I/O contention
    private let preloadSemaphore = DispatchSemaphore(value: 4)
    
    /// PERF: Track keys currently being loaded to avoid duplicate work
    private var loadingKeys = Set<String>()
    private let loadingKeysLock = NSLock()
    
    /// PERF: Memory limit for in-memory cache (50MB)
    private let maxCacheMemoryBytes: Int = 50 * 1024 * 1024
    private var currentCacheMemoryBytes: Int = 0
    
    /// PERF: Maximum image dimensions for storage (reduces disk usage and memory)
    private let maxImageDimension: CGFloat = 2048
    private let thumbnailSize: CGSize = CGSize(width: 300, height: 300)
    
    // Directory for storing photos
    private var photosDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosPath = documentsPath.appendingPathComponent("VisitPhotos")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: photosPath.path) {
            try? FileManager.default.createDirectory(at: photosPath, withIntermediateDirectories: true)
        }
        
        return photosPath
    }
    
    private init() {
        // PERF: Listen for memory warnings and clear memory cache
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        #if DEBUG
        print("⚠️ [PhotoCache] Memory warning received - clearing memory cache")
        #endif
        
        queue.async(flags: .barrier) {
            let oldCount = self.cache.count
            self.cache.removeAll()
            self.thumbnailCache.removeAll()
            self.currentCacheMemoryBytes = 0
            
            #if DEBUG
            print("⚠️ [PhotoCache] Cleared \(oldCount) images from memory")
            #endif
        }
    }
    
    // PERF: Downscale image if it exceeds max dimensions
    private func downscaleImageIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size
        let maxDim = max(size.width, size.height)
        
        // No need to downscale if within limits
        guard maxDim > maxImageDimension else {
            return image
        }
        
        let scale = maxImageDimension / maxDim
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // PERF: Generate thumbnail for grid views
    private func generateThumbnail(from image: UIImage) -> UIImage {
        let size = image.size
        let scale = min(thumbnailSize.width / size.width, thumbnailSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // PERF: Estimate memory footprint of image
    private func estimateImageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
    
    // PERF: Enforce memory limit by evicting oldest images
    private func enforceMemoryLimit() {
        guard currentCacheMemoryBytes > maxCacheMemoryBytes else { return }
        
        // Remove 25% of cache to avoid thrashing
        let targetBytes = Int(Double(maxCacheMemoryBytes) * 0.75)
        
        #if DEBUG
        print("⚠️ [PhotoCache] Memory limit exceeded (\(currentCacheMemoryBytes / 1024 / 1024)MB), evicting to \(targetBytes / 1024 / 1024)MB")
        #endif
        
        // Simple eviction: clear half the cache
        // (A proper LRU would be better but adds complexity)
        let keysToRemove = Array(cache.keys.prefix(cache.count / 2))
        for key in keysToRemove {
            if let image = cache[key] {
                currentCacheMemoryBytes -= estimateImageMemorySize(image)
                cache.removeValue(forKey: key)
            }
        }
    }
    
    // Store image both in memory and on disk
    func store(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            // PERF: Downscale image before storing to save memory and disk space
            let scaledImage = self.downscaleImageIfNeeded(image)
            
            // Store in memory cache
            self.cache[key] = scaledImage
            let memorySize = self.estimateImageMemorySize(scaledImage)
            self.currentCacheMemoryBytes += memorySize
            
            // PERF: Enforce memory limit
            self.enforceMemoryLimit()
            
            // PERF: Generate and cache thumbnail
            let thumbnail = self.generateThumbnail(from: scaledImage)
            self.thumbnailCache[key] = thumbnail
            
            // Store on disk
            let fileURL = self.photosDirectory.appendingPathComponent("\(key).jpg")
            
            // Compress and save image as JPEG
            if let imageData = scaledImage.jpegData(compressionQuality: 0.8) {
                try? imageData.write(to: fileURL)
            }
        }
    }
    
    // Retrieve thumbnail for grid views (faster, uses less memory)
    func retrieveThumbnail(forKey key: String) -> UIImage? {
        return queue.sync {
            if let thumbnail = thumbnailCache[key] {
                return thumbnail
            }
            
            // If full image is in cache, generate thumbnail from it
            if let fullImage = cache[key] {
                let thumbnail = generateThumbnail(from: fullImage)
                thumbnailCache[key] = thumbnail
                return thumbnail
            }
            
            return nil
        }
    }
    
    // Retrieve image from memory cache or disk
    func retrieve(forKey key: String) -> UIImage? {
        return queue.sync {
            // First check memory cache
            if let cachedImage = cache[key] {
                return cachedImage
            }
            
            // If not in memory, try to load from disk
            let fileURL = photosDirectory.appendingPathComponent("\(key).jpg")
            
            if FileManager.default.fileExists(atPath: fileURL.path),
               let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                // Store in memory cache for future access
                cache[key] = image
                return image
            }
            
            return nil
        }
    }
    
    /// PERFORMANCE: Async retrieve that doesn't block main thread
    func retrieveAsync(forKey key: String, completion: @escaping (UIImage?) -> Void) {
        // First check memory cache synchronously (fast path)
        if let cachedImage = queue.sync(execute: { cache[key] }) {
            completion(cachedImage)
            return
        }
        
        // Load from disk asynchronously
        queue.async {
            let fileURL = self.photosDirectory.appendingPathComponent("\(key).jpg")
            
            if FileManager.default.fileExists(atPath: fileURL.path),
               let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                // Store in memory cache for future access
                self.queue.async(flags: .barrier) {
                    self.cache[key] = image
                }
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // Clear memory cache (disk files remain)
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self.thumbnailCache.removeAll()
            self.currentCacheMemoryBytes = 0
        }
        loadingKeysLock.lock()
        loadingKeys.removeAll()
        loadingKeysLock.unlock()
    }
    
    // Clean up old files from disk (older than 7 days)
    func cleanDiskCache() {
        queue.async {
            let fileManager = FileManager.default
            let directory = self.photosDirectory
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            do {
                let resourceKeys: [URLResourceKey] = [.contentModificationDateKey]
                let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: resourceKeys)
                
                for file in files {
                    if let resources = try? file.resourceValues(forKeys: Set(resourceKeys)),
                       let modificationDate = resources.contentModificationDate,
                       modificationDate < sevenDaysAgo {
                        try? fileManager.removeItem(at: file)
                        print("[PhotoCache] Cleaned up old file: \(file.lastPathComponent)")
                    }
                }
            } catch {
                print("⚠️ [PhotoCache] Cleanup error: \(error)")
            }
        }
    }
    
    // PERFORMANCE: Preload images with limited concurrency and deduplication
    func preloadImages(for photoPaths: [String]) {
        // PERFORMANCE: Limit preload batch size to avoid memory pressure
        let pathsToPreload = Array(photoPaths.prefix(50))
        
        queue.async {
            for path in pathsToPreload {
                // Skip if already in cache
                if self.cache[path] != nil {
                    continue
                }
                
                // Skip if currently loading
                self.loadingKeysLock.lock()
                if self.loadingKeys.contains(path) {
                    self.loadingKeysLock.unlock()
                    continue
                }
                self.loadingKeys.insert(path)
                self.loadingKeysLock.unlock()
                
                // PERFORMANCE: Limit concurrent disk I/O
                self.preloadSemaphore.wait()
                defer {
                    self.preloadSemaphore.signal()
                    self.loadingKeysLock.lock()
                    self.loadingKeys.remove(path)
                    self.loadingKeysLock.unlock()
                }
                
                // Load from disk if not in memory
                let fileURL = self.photosDirectory.appendingPathComponent("\(path).jpg")
                
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let imageData = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: imageData) {
                    // Store in memory cache
                    self.queue.async(flags: .barrier) {
                        self.cache[path] = image
                    }
                }
            }
        }
    }
    
    /// PERFORMANCE: Check if image is in memory cache without disk I/O
    func hasImageInMemory(forKey key: String) -> Bool {
        return queue.sync { cache[key] != nil }
    }
}

