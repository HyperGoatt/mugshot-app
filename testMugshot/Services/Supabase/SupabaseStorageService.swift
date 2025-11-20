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

    /// Uploads an image to Supabase Storage and returns the public URL path.
    func uploadImage(_ image: UIImage, path: String, bucket: String? = nil) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw SupabaseError.network("Could not encode JPEG data")
        }
        
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
            throw SupabaseError.server(status: response.statusCode, message: String(data: responseData, encoding: .utf8))
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


