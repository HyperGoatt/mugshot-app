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
    
    // Clear memory cache (disk files remain)
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
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
                    self.cache[path] = image
                }
            }
        }
    }
}

