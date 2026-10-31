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

    static func validate(
        userID: UUID, visitID: UUID, imageCount: Int,
        paths: [String], completedPaths: [String]
    ) throws {
        let prefix = "\(userID.uuidString.lowercased())/\(visitID.uuidString.lowercased())/"
        guard imageCount <= maxPhotoCount, paths.count == imageCount,
              Set(paths).count == paths.count,
              Set(completedPaths).isSubset(of: Set(paths)),
              paths.allSatisfy({ path in
                  path.hasPrefix(prefix) && !path.dropFirst(prefix.count).isEmpty
                      && !path.dropFirst(prefix.count).contains("/")
                      && !path.contains("..")
              }) else { throw VisitPhotoUploadError.invalidUploadPlan }
    }

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
        replacingExisting: Bool = false,
        completedObjectPaths: [String] = [],
        onPhotoUploaded: ((String) throws -> Void)? = nil
    ) async throws -> UploadedVisitPhotos {
        try await uploadPlannedPhotos(
            userId: userId, visitId: visitId, images: images.map(Optional.some),
            posterPhotoIndex: posterPhotoIndex, plannedObjectPaths: plannedObjectPaths,
            replacingExisting: replacingExisting, completedObjectPaths: completedObjectPaths,
            onPhotoUploaded: onPhotoUploaded
        )
    }

    /// Acknowledged photos need no local bytes. Nil is accepted only for an
    /// exact durable acknowledgement in the account/visit-scoped frozen plan.
    func uploadPlannedPhotos(
        userId: UUID, visitId: UUID, images: [UIImage?], posterPhotoIndex: Int,
        plannedObjectPaths: [String]? = nil, replacingExisting: Bool = false,
        completedObjectPaths: [String] = [],
        onPhotoUploaded: ((String) throws -> Void)? = nil
    ) async throws -> UploadedVisitPhotos {
        try Task.checkCancellation()
        let paths = plannedObjectPaths ?? VisitPhotoUploadPlan.objectPaths(
            userId: userId, visitId: visitId, objectIds: images.map { _ in UUID() }
        )
        try VisitPhotoUploadPlan.validate(
            userID: userId, visitID: visitId, imageCount: images.count,
            paths: paths, completedPaths: completedObjectPaths
        )
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
        let uploadImages = images
        let completed = Set(completedObjectPaths)
        guard completed.isSubset(of: Set(paths)),
              completed.isEmpty || (plannedObjectPaths != nil && onPhotoUploaded != nil) else {
            throw VisitPhotoUploadError.invalidUploadPlan
        }
        var diagnosticOutcome = BatteryDiagnostics.WorkOutcome.interrupted
        var diagnostics = BatteryDiagnostics.PhotoUploadSession(
            plannedPhotoCount: uploadImages.count
        )
        defer { diagnostics.finish(diagnosticOutcome) }

        do {
            for (image, path) in zip(uploadImages, paths) {
                try Task.checkCancellation()
                guard let reference = VisitPhotoStorageReference(
                    bucketName: bucketName,
                    objectPath: path
                ) else {
                    throw VisitPhotoUploadError.invalidUploadPlan
                }
                if !completed.contains(path) {
                    guard let image else {
                        throw PendingVisitSubmissionStoreError.missingLocalPhoto
                    }
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
                    diagnostics.recordedUpload(byteCount: data.count)
                    // Persist before observing a late cancellation. The server
                    // has acknowledged these bytes even if the app is closing.
                    try onPhotoUploaded?(path)
                }
                attachmentReferences.append(reference.storedValue)
            }
        } catch {
            diagnosticOutcome = Task.isCancelled ? .cancelled : .failed
            // Protected publication owns its frozen plan and keeps successful
            // objects for retry. One-shot edit uploads retain rollback cleanup.
            if onPhotoUploaded == nil, !objectPaths.isEmpty {
                _ = try? await storage.remove(paths: objectPaths)
            }
            throw error
        }

        try Task.checkCancellation()
        let safePosterIndex = attachmentReferences.indices.contains(posterPhotoIndex)
            ? posterPhotoIndex
            : 0
        diagnosticOutcome = .completed
        return UploadedVisitPhotos(
            attachmentReferences: attachmentReferences,
            objectPaths: paths,
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
