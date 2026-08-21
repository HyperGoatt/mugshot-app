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

    func uploadBanner(userId: UUID, image: UIImage) async throws -> String {
        let normalized = image.profileBanner(maxWidth: 1600)
        guard let data = normalized.jpegData(compressionQuality: 0.84) else {
            throw ProfileMediaError.encodingFailed
        }

        let path = "\(userId.uuidString.lowercased())/banner-\(UUID().uuidString.lowercased()).jpg"
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
        await removeProfileMedia(at: publicURL)
    }

    func removeBanner(at publicURL: String?) async {
        await removeProfileMedia(at: publicURL)
    }

    private func removeProfileMedia(at publicURL: String?) async {
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

    func profileBanner(maxWidth: CGFloat) -> UIImage {
        let targetRatio: CGFloat = 3
        let sourceRatio = size.width / max(size.height, 1)
        let cropSize: CGSize
        if sourceRatio > targetRatio {
            cropSize = CGSize(width: size.height * targetRatio, height: size.height)
        } else {
            cropSize = CGSize(width: size.width, height: size.width / targetRatio)
        }
        let cropOrigin = CGPoint(
            x: (size.width - cropSize.width) / 2,
            y: (size.height - cropSize.height) / 2
        )
        let outputWidth = min(maxWidth, cropSize.width)
        let outputSize = CGSize(width: outputWidth, height: outputWidth / targetRatio)
        let scale = outputWidth / cropSize.width
        return UIGraphicsImageRenderer(size: outputSize).image { _ in
            draw(in: CGRect(
                x: -cropOrigin.x * scale,
                y: -cropOrigin.y * scale,
                width: size.width * scale,
                height: size.height * scale
            ))
        }
    }
}
