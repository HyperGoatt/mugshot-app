//
//  ProfileMediaService.swift
//  testMugshot
//

import Foundation
import Supabase
import UIKit

final class ProfileMediaService {
    private let client: SupabaseClient
    private let bucketName = "profile-media"

    init(client: SupabaseClient) {
        self.client = client
    }

    func uploadAvatar(userId: UUID, image: UIImage) async throws -> String {
        let normalized = image.squareAvatar(maxDimension: 512)
        guard let data = normalized.jpegData(compressionQuality: 0.82) else {
            throw ProfileMediaError.encodingFailed
        }

        let path = "\(userId.uuidString.lowercased())/avatar-\(UUID().uuidString.lowercased()).jpg"
        let storage = client.storage.from(bucketName)
        try await storage.upload(
            path,
            data: data,
            options: FileOptions(
                cacheControl: "31536000",
                contentType: "image/jpeg",
                upsert: false
            )
        )
        return try storage.getPublicURL(path: path).absoluteString
    }

    func removeAvatar(at publicURL: String?) async {
        guard let publicURL,
              let url = URL(string: publicURL),
              let range = url.path.range(of: "/object/public/\(bucketName)/") else {
            return
        }

        let path = String(url.path[range.upperBound...])
        _ = try? await client.storage.from(bucketName).remove(paths: [path])
    }
}

enum ProfileMediaError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "We couldn’t prepare that photo. Please choose another one."
    }
}

private extension UIImage {
    func squareAvatar(maxDimension: CGFloat) -> UIImage {
        let sourceSize = size
        let side = min(sourceSize.width, sourceSize.height)
        let cropRect = CGRect(
            x: (sourceSize.width - side) / 2,
            y: (sourceSize.height - side) / 2,
            width: side,
            height: side
        )
        let target = CGSize(width: maxDimension, height: maxDimension)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            let scale = maxDimension / side
            let drawRect = CGRect(
                x: -cropRect.origin.x * scale,
                y: -cropRect.origin.y * scale,
                width: sourceSize.width * scale,
                height: sourceSize.height * scale
            )
            draw(in: drawRect)
        }
    }
}
