//
//  PhotoCache.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import UIKit

final class PhotoCache: @unchecked Sendable {
    static let shared = PhotoCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "com.mugshot.photocache", attributes: .concurrent)
    
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
        cache.totalCostLimit = 32 * 1_024 * 1_024
        cache.countLimit = 40
    }
    
    // Store image both in memory and on disk
    func store(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            // Store in memory cache
            self.cache.setObject(image, forKey: key as NSString, cost: image.memoryCost)
            
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
            if let cachedImage = cache.object(forKey: key as NSString) {
                return cachedImage
            }
            
            // If not in memory, try to load from disk
            let fileURL = photosDirectory.appendingPathComponent("\(key).jpg")
            
            if FileManager.default.fileExists(atPath: fileURL.path),
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
        let fileURL = photosDirectory.appendingPathComponent("\(key).jpg")
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
                let fileURL = self.photosDirectory.appendingPathComponent("\(path).jpg")
                
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let imageData = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: imageData) {
                    // Store in memory cache
                    self.cache.setObject(image, forKey: path as NSString, cost: image.memoryCost)
                }
            }
        }
    }
}

private extension UIImage {
    var memoryCost: Int {
        cgImage.map { $0.bytesPerRow * $0.height } ?? Int(size.width * size.height * 4)
    }
}
