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
    private let queue = DispatchQueue(label: "com.mugshot.photocache", attributes: .concurrent)
    
    /// PERFORMANCE: Limit concurrent preloads to avoid I/O contention
    private let preloadSemaphore = DispatchSemaphore(value: 4)
    
    /// PERFORMANCE: Track keys currently being loaded to avoid duplicate work
    private var loadingKeys = Set<String>()
    private let loadingKeysLock = NSLock()
    
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
    
    private init() {}
    
    // Store image both in memory and on disk
    func store(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            // Store in memory cache
            self.cache[key] = image
            
            // Store on disk
            let fileURL = self.photosDirectory.appendingPathComponent("\(key).jpg")
            
            // Compress and save image as JPEG
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                try? imageData.write(to: fileURL)
            }
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

