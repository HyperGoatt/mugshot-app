//
//  SupabaseStorageService.swift
//  testMugshot
//

import Foundation
import UIKit

final class SupabaseStorageService {
    static let shared = SupabaseStorageService(client: SupabaseClientProvider.shared)

    private let client: SupabaseClient
    private let bucketName = "profile-media"

    init(client: SupabaseClient) {
        self.client = client
    }

    // Maximum file size for uploads (2MB to stay well under Supabase limits)
    private let maxFileSizeBytes = 2 * 1024 * 1024
    
    /// Resizes an image to a maximum dimension while maintaining aspect ratio.
    /// - Parameters:
    ///   - image: The image to resize
    ///   - maxDimension: Maximum width or height (default: 1200px for optimal mobile viewing)
    /// - Returns: Resized image
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat = 1200) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)
        
        // If image is already smaller than max dimension, return as-is
        guard maxSize > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Create graphics context and draw resized image
        // Use scale 1.0 to avoid retina doubling which increases file size
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        return resizedImage
    }
    
    /// Compresses image data to be under the max file size limit
    private func compressToMaxSize(_ image: UIImage, initialQuality: CGFloat = 0.7) -> Data? {
        var quality = initialQuality
        var data = image.jpegData(compressionQuality: quality)
        
        // Progressively reduce quality until under limit (min quality 0.3)
        while let currentData = data, currentData.count > maxFileSizeBytes && quality > 0.3 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality)
            #if DEBUG
            print("📸 [StorageService] Recompressing at quality \(String(format: "%.1f", quality)) - size: \(currentData.count / 1024)KB")
            #endif
        }
        
        return data
    }
    
    /// Uploads an image to Supabase Storage and returns the public URL path.
    /// Images are automatically resized to 1200px max and compressed to under 2MB.
    func uploadImage(_ image: UIImage, path: String, bucket: String? = nil) async throws -> String {
        // Resize image to prevent payload size issues (1200px is good for mobile)
        let resizedImage = resizeImage(image, maxDimension: 1200)
        
        // Compress with progressive quality reduction to stay under size limit
        guard let data = compressToMaxSize(resizedImage, initialQuality: 0.7) else {
            throw SupabaseError.network("Could not encode JPEG data")
        }
        
        // Final size check
        if data.count > maxFileSizeBytes {
            print("❌ [StorageService] Image still too large after max compression: \(data.count / 1024)KB")
            throw SupabaseError.server(
                status: 413,
                message: "Image is too large even after compression. Please try a smaller image."
            )
        }
        
        #if DEBUG
        let originalSize = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        let finalSize = data.count
        let sizeReduction = originalSize > 0 ? Double(finalSize) / Double(originalSize) * 100 : 0
        print("📸 [StorageService] Image upload - Original: \(originalSize / 1024)KB, Final: \(finalSize / 1024)KB (\(String(format: "%.1f", sizeReduction))%)")
        print("📸 [StorageService] Image dimensions - Original: \(image.size), Resized: \(resizedImage.size)")
        #endif
        
        let resolvedBucket = bucket ?? bucketName

        let storagePath = "storage/v1/object/\(resolvedBucket)/\(path)"

        let (responseData, response) = try await client.request(
            path: storagePath,
            method: "POST",
            headers: [
                "Content-Type": "image/jpeg",
                "x-upsert": "true"
            ],
            body: data
        )

        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            
            // Provide user-friendly message for payload too large errors
            if response.statusCode == 413 {
                print("❌ [StorageService] Payload too large - image size: \(data.count / 1024)KB")
                throw SupabaseError.server(
                    status: response.statusCode,
                    message: "Image is too large. Please try a smaller image or reduce the number of photos."
                )
            }
            
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }

        let keyPath: String
        if
            let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let key = json["Key"] as? String {
            keyPath = key
        } else {
            keyPath = "\(resolvedBucket)/\(path)"
        }

        return publicURL(for: keyPath)
    }

    private func publicURL(for key: String) -> String {
        let trimmedKey = key.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let publicPath = "storage/v1/object/public/\(trimmedKey)"
        let url = URL(string: publicPath, relativeTo: client.baseURL) ?? client.baseURL
        return url.absoluteString
    }
}


