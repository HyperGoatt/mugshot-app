import Foundation
import UIKit

enum PendingVisitSubmissionPhase: Int, Codable, Comparable {
    case prepared
    case visitCreated
    case photosUploaded

    static func < (lhs: PendingVisitSubmissionPhase, rhs: PendingVisitSubmissionPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PendingVisitSubmissionRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let userId: UUID
    let cafe: Cafe?
    let entryContext: JournalEntryContext?
    let locationName: String?
    let drinkType: DrinkType
    let customDrinkType: String?
    let drinkSubtype: String
    let caption: String
    let notes: String?
    let brewMethod: String?
    let equipment: String?
    let brewDetails: BrewDetails?
    let visibility: VisitVisibility
    let ratings: [String: Double]
    let ratingTemplate: RatingTemplate
    let posterPhotoIndex: Int
    let localPhotoNames: [String]
    let objectPaths: [String]
    let createdAt: Date
    var phase: PendingVisitSubmissionPhase
    var uploadedPhotoURLs: [String]?

    var resolvedEntryContext: JournalEntryContext {
        entryContext ?? .cafe
    }

    var resolvedBrewDetails: BrewDetails {
        brewDetails ?? .empty
    }
}

final class PendingVisitSubmissionStore {
    static let shared = PendingVisitSubmissionStore()

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let keyPrefix = "MugshotPendingVisitSubmission.v1."

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MugshotPendingVisits", isDirectory: true)
    }

    func prepare(
        userId: UUID,
        cafe: Cafe?,
        entryContext: JournalEntryContext = .cafe,
        locationName: String? = nil,
        drinkType: DrinkType,
        customDrinkType: String?,
        drinkSubtype: String,
        caption: String,
        notes: String?,
        brewMethod: String? = nil,
        equipment: String? = nil,
        brewDetails: BrewDetails = .empty,
        visibility: VisitVisibility,
        ratings: [String: Double],
        ratingTemplate: RatingTemplate,
        images: [UIImage],
        posterPhotoIndex: Int
    ) throws -> PendingVisitSubmissionRecord {
        let visitId = UUID()
        let directory = visitDirectory(visitId)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var localNames: [String] = []
        do {
            for (index, image) in images.prefix(VisitPhotoUploadPlan.maxPhotoCount).enumerated() {
                let name = "photo-\(index).jpg"
                guard let data = image
                    .resizedForVisitUpload(maxDimension: 2_000)
                    .jpegData(compressionQuality: 0.82) else {
                    throw PendingVisitSubmissionStoreError.photoEncodingFailed
                }
                try data.write(to: directory.appendingPathComponent(name), options: .atomic)
                localNames.append(name)
            }
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }

        let objectPaths = VisitPhotoUploadPlan.objectPaths(
            userId: userId,
            visitId: visitId,
            objectIds: localNames.map { _ in UUID() }
        )
        let record = PendingVisitSubmissionRecord(
            id: visitId,
            userId: userId,
            cafe: cafe,
            entryContext: entryContext,
            locationName: locationName,
            drinkType: drinkType,
            customDrinkType: customDrinkType,
            drinkSubtype: drinkSubtype,
            caption: caption,
            notes: notes,
            brewMethod: brewMethod,
            equipment: equipment,
            brewDetails: brewDetails,
            visibility: visibility,
            ratings: ratings,
            ratingTemplate: ratingTemplate,
            posterPhotoIndex: min(max(posterPhotoIndex, 0), max(localNames.count - 1, 0)),
            localPhotoNames: localNames,
            objectPaths: objectPaths,
            createdAt: Date(),
            phase: .prepared,
            uploadedPhotoURLs: nil
        )
        try save(record)
        return record
    }

    func save(_ record: PendingVisitSubmissionRecord) throws {
        defaults.set(try JSONEncoder().encode(record), forKey: storageKey(record.userId))
    }

    func load(userId: UUID) -> PendingVisitSubmissionRecord? {
        guard let data = defaults.data(forKey: storageKey(userId)) else { return nil }
        return try? JSONDecoder().decode(PendingVisitSubmissionRecord.self, from: data)
    }

    func loadImages(for record: PendingVisitSubmissionRecord) throws -> [UIImage] {
        try record.localPhotoNames.map { name in
            let url = visitDirectory(record.id).appendingPathComponent(name)
            guard let image = UIImage(contentsOfFile: url.path) else {
                throw PendingVisitSubmissionStoreError.missingLocalPhoto
            }
            return image
        }
    }

    func remove(_ record: PendingVisitSubmissionRecord) {
        defaults.removeObject(forKey: storageKey(record.userId))
        try? fileManager.removeItem(at: visitDirectory(record.id))
    }

    private func storageKey(_ userId: UUID) -> String {
        keyPrefix + userId.uuidString.lowercased()
    }

    private func visitDirectory(_ visitId: UUID) -> URL {
        baseDirectory.appendingPathComponent(visitId.uuidString.lowercased(), isDirectory: true)
    }
}

enum PendingVisitSubmissionStoreError: LocalizedError {
    case photoEncodingFailed
    case missingLocalPhoto

    var errorDescription: String? {
        switch self {
        case .photoEncodingFailed:
            return "One selected photo could not be prepared for upload."
        case .missingLocalPhoto:
            return "A saved draft photo is missing. Discard this draft and try again."
        }
    }
}
