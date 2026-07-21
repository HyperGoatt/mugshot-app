//
//  VisitPhotoUploadService.swift
//  testMugshot
//

import Foundation
import Supabase
import UIKit

struct UploadedVisitPhotos: Equatable {
    let attachmentReferences: [String]
    let objectPaths: [String]
    let posterPhotoIndex: Int

    /// Compatibility alias for pending submission records created before
    /// private Storage references replaced public URLs.
    var publicURLs: [String] {
        attachmentReferences
    }

    var posterPhotoURL: String? {
        guard attachmentReferences.indices.contains(posterPhotoIndex) else {
            return attachmentReferences.first
        }

        return attachmentReferences[posterPhotoIndex]
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
    private let bucketName = VisitPhotoStorageReference.privateBucketName
    private let maxUploadBytes = 9_500_000

    init(client: SupabaseClient) {
        self.client = client
    }

    func uploadPhotos(
        userId: UUID,
        visitId: UUID,
        images: [UIImage],
        posterPhotoIndex: Int,
        plannedObjectPaths: [String]? = nil,
        replacingExisting: Bool = false
    ) async throws -> UploadedVisitPhotos {
        guard !images.isEmpty else {
            return UploadedVisitPhotos(
                attachmentReferences: [],
                objectPaths: [],
                posterPhotoIndex: 0
            )
        }

        let storage = client.storage.from(bucketName)
        var attachmentReferences: [String] = []
        var objectPaths: [String] = []
        let uploadImages = Array(images.prefix(VisitPhotoUploadPlan.maxPhotoCount))
        let paths = plannedObjectPaths ?? VisitPhotoUploadPlan.objectPaths(
            userId: userId,
            visitId: visitId,
            objectIds: uploadImages.map { _ in UUID() }
        )
        guard paths.count == uploadImages.count else {
            throw VisitPhotoUploadError.invalidUploadPlan
        }

        do {
            for (image, path) in zip(uploadImages, paths) {
                let data = try jpegData(for: image)

                try await storage.upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "31536000",
                        contentType: "image/jpeg",
                        upsert: replacingExisting
                    )
                )

                objectPaths.append(path)
                guard let reference = VisitPhotoStorageReference(
                    bucketName: bucketName,
                    objectPath: path
                ) else {
                    throw VisitPhotoUploadError.invalidUploadPlan
                }
                attachmentReferences.append(reference.storedValue)
            }
        } catch {
            if !objectPaths.isEmpty {
                _ = try? await storage.remove(paths: objectPaths)
            }
            throw error
        }

        let safePosterIndex = attachmentReferences.indices.contains(posterPhotoIndex)
            ? posterPhotoIndex
            : 0
        return UploadedVisitPhotos(
            attachmentReferences: attachmentReferences,
            objectPaths: objectPaths,
            posterPhotoIndex: safePosterIndex
        )
    }

    func deletePhotos(at objectPaths: [String]) async throws {
        try await deletePhotos(at: objectPaths.map {
            VisitPhotoStorageLocation(bucketName: bucketName, objectPath: $0)
        })
    }

    func deletePhotos(at locations: [VisitPhotoStorageLocation]) async throws {
        let locationsByBucket = Dictionary(grouping: Set(locations), by: \.bucketName)
        for (bucketName, bucketLocations) in locationsByBucket {
            try await client.storage.from(bucketName).remove(
                paths: bucketLocations.map(\.objectPath).sorted()
            )
        }
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
    case invalidUploadPlan

    var errorDescription: String? {
        switch self {
        case .imageTooLarge:
            return "One photo is too large to upload. Try a smaller image."
        case .invalidUploadPlan:
            return "The saved upload plan no longer matches its photos. Discard the draft and try again."
        }
    }
}

extension UIImage {
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
