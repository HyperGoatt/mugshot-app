//
//  VisitPhotoUploadService.swift
//  testMugshot
//

import Foundation
import Supabase
import UIKit

struct UploadedVisitPhotos: Equatable {
    let publicURLs: [String]
    let objectPaths: [String]
    let posterPhotoIndex: Int

    var posterPhotoURL: String? {
        guard publicURLs.indices.contains(posterPhotoIndex) else {
            return publicURLs.first
        }

        return publicURLs[posterPhotoIndex]
    }
}

struct VisitPhotoUploadPlan {
    static let maxPhotoCount = 10

    static func objectPath(
        userId: UUID,
        visitId: UUID,
        objectId: UUID,
        fileExtension: String = "jpg"
    ) -> String {
        [
            userId.uuidString.lowercased(),
            visitId.uuidString.lowercased(),
            "\(objectId.uuidString.lowercased()).\(fileExtension.lowercased())"
        ].joined(separator: "/")
    }

    static func objectPaths(
        userId: UUID,
        visitId: UUID,
        objectIds: [UUID],
        fileExtension: String = "jpg"
    ) -> [String] {
        objectIds
            .prefix(maxPhotoCount)
            .map { objectPath(userId: userId, visitId: visitId, objectId: $0, fileExtension: fileExtension) }
    }
}

final class VisitPhotoUploadService {
    private let client: SupabaseClient
    private let bucketName = "visit-photos"
    private let maxUploadBytes = 9_500_000

    init(client: SupabaseClient) {
        self.client = client
    }

    func uploadPhotos(
        userId: UUID,
        visitId: UUID,
        images: [UIImage],
        posterPhotoIndex: Int
    ) async throws -> UploadedVisitPhotos {
        guard !images.isEmpty else {
            return UploadedVisitPhotos(publicURLs: [], objectPaths: [], posterPhotoIndex: 0)
        }

        let storage = client.storage.from(bucketName)
        var publicURLs: [String] = []
        var objectPaths: [String] = []

        do {
            for image in images.prefix(VisitPhotoUploadPlan.maxPhotoCount) {
                let data = try jpegData(for: image)
                let path = VisitPhotoUploadPlan.objectPath(
                    userId: userId,
                    visitId: visitId,
                    objectId: UUID()
                )

                try await storage.upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "31536000",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )

                objectPaths.append(path)
                publicURLs.append(try storage.getPublicURL(path: path).absoluteString)
            }
        } catch {
            if !objectPaths.isEmpty {
                _ = try? await storage.remove(paths: objectPaths)
            }
            throw error
        }

        let safePosterIndex = publicURLs.indices.contains(posterPhotoIndex) ? posterPhotoIndex : 0
        return UploadedVisitPhotos(
            publicURLs: publicURLs,
            objectPaths: objectPaths,
            posterPhotoIndex: safePosterIndex
        )
    }

    func deletePhotos(at objectPaths: [String]) async throws {
        guard !objectPaths.isEmpty else { return }
        try await client.storage.from(bucketName).remove(paths: objectPaths)
    }

    private func jpegData(for image: UIImage) throws -> Data {
        let resized = image.resizedForVisitUpload(maxDimension: 2_000)
        let qualities: [CGFloat] = [0.82, 0.72, 0.62, 0.52]

        for quality in qualities {
            guard let data = resized.jpegData(compressionQuality: quality) else {
                continue
            }

            if data.count <= maxUploadBytes {
                return data
            }
        }

        throw VisitPhotoUploadError.imageTooLarge
    }
}

enum VisitPhotoUploadError: LocalizedError, Equatable {
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .imageTooLarge:
            return "One photo is too large to upload. Try a smaller image."
        }
    }
}

private extension UIImage {
    func resizedForVisitUpload(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return self
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
