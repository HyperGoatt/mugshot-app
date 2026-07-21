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

/// Frozen Cafe Session metadata that travels with a single durable sip
/// submission. Keeping this beside the prepared media plan means every retry
/// uses the same session, visit, snapshot, and sharing decisions.
struct PendingCafeSessionLink: Codable, Equatable {
    let sessionID: UUID
    let startedAt: Date
    let sipOrder: Int
    let sipRole: CafeSessionSipRole
    let visitContext: CafeVisitContext
    let returnIntention: CafeReturnIntention?
    let reorderIntention: SipReorderIntention?
    let repeatComparison: CafeRepeatComparison?
    let experienceSnapshot: CafeExperienceSnapshot?
    let shareProjection: CafeExperienceShareProjection
}

struct PendingVisitSubmissionRecord: Codable, Equatable, Identifiable {
    static let maximumRawNoteLength = 10_000

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
    let overallScore: Double?
    let ratingTemplate: RatingTemplate
    let sensorySnapshot: SipSensorySnapshot?
    let v3Reflection: V3VisitReflection?
    /// Frozen account identities for shared-memory recovery. Optional keeps
    /// pending records written before companion persistence decodable.
    let taggedCompanions: [SipCompanion]?
    var posterPhotoIndex: Int
    var localPhotoNames: [String]
    var objectPaths: [String]
    let createdAt: Date
    var phase: PendingVisitSubmissionPhase
    var uploadedPhotoURLs: [String]?
    var cafeSession: PendingCafeSessionLink? = nil

    var resolvedEntryContext: JournalEntryContext {
        entryContext ?? .cafe
    }

    var resolvedBrewDetails: BrewDetails {
        brewDetails ?? .empty
    }

    var resolvedOverallScore: Double {
        if let overallScore, overallScore >= 0.5, overallScore <= 5, overallScore.isFinite {
            return overallScore
        }
        return ratingTemplate.calculateOverallScore(ratings: ratings)
    }

    var retryPayloadIssue: PendingVisitRetryPayloadIssue? {
        if Self.exceedsRawNoteLimit(notes)
            || Self.exceedsRawNoteLimit(v3Reflection?.sipRawNote) {
            return .sipRawNoteExceedsLimit
        }
        if Self.exceedsRawNoteLimit(v3Reflection?.contextRawNote) {
            return .contextRawNoteExceedsLimit
        }
        return nil
    }

    var hasValidRetryPayload: Bool {
        retryPayloadIssue == nil
    }

    /// A pending submission may only resume through the draft that originally
    /// created its stable visit ID. Session identity is checked separately so
    /// an account-scoped recovery can never be attached to another cafe visit.
    func canResume(with draft: SipDraft, authenticatedUserID: UUID) -> Bool {
        guard id == draft.id,
              userId == authenticatedUserID,
              draft.ownerUserID == nil || draft.ownerUserID == authenticatedUserID,
              resolvedEntryContext == draft.context,
              cafesReferToSamePlace(cafe, draft.cafe) else {
            return false
        }

        let pendingSessionID = cafeSession?.sessionID
        guard pendingSessionID == draft.cafeSessionID else { return false }

        if let cafeSession {
            guard cafeSession.sipOrder == draft.cafeSessionSipOrder,
                  cafeSession.sipRole == draft.cafeSessionSipRole else {
                return false
            }
            if let snapshot = cafeSession.experienceSnapshot {
                guard snapshot.ownerUserID == authenticatedUserID,
                      snapshot.sessionID == cafeSession.sessionID else {
                    return false
                }
            }
            if let sessionOwner = draft.cafeSessionDraft?.ownerUserID
                ?? draft.cafeSessionReference?.ownerUserID,
               sessionOwner != authenticatedUserID {
                return false
            }
        } else if draft.cafeSessionSipOrder != nil || draft.cafeSessionSipRole != nil {
            return false
        }

        return true
    }

    private func cafesReferToSamePlace(_ lhs: Cafe?, _ rhs: Cafe?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            if lhs.id == rhs.id { return true }
            if let lhsRemoteID = lhs.remoteCafeId,
               let rhsRemoteID = rhs.remoteCafeId {
                return lhsRemoteID == rhsRemoteID
            }
            return false
        default:
            return false
        }
    }

    private static func exceedsRawNoteLimit(_ note: String?) -> Bool {
        guard let note else { return false }
        // PostgreSQL char_length counts Unicode characters rather than bytes.
        // Scalars are a conservative match for that server-side constraint.
        return note.unicodeScalars.count > maximumRawNoteLength
    }
}

enum PendingVisitRetryPayloadIssue: LocalizedError, Equatable {
    case sipRawNoteExceedsLimit
    case contextRawNoteExceedsLimit

    var errorDescription: String? {
        switch self {
        case .sipRawNoteExceedsLimit:
            return "The sip journal note is longer than 10,000 characters."
        case .contextRawNoteExceedsLimit:
            return "The context journal note is longer than 10,000 characters."
        }
    }
}

struct PendingVisitMediaReplacement: Equatable {
    let record: PendingVisitSubmissionRecord
    let obsoleteObjectPaths: [String]
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
        visitId: UUID = UUID(),
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
        overallScore: Double? = nil,
        ratingTemplate: RatingTemplate,
        sensorySnapshot: SipSensorySnapshot? = nil,
        v3Reflection: V3VisitReflection? = nil,
        taggedCompanions: [SipCompanion]? = nil,
        cafeSession: PendingCafeSessionLink? = nil,
        images: [UIImage],
        posterPhotoIndex: Int
    ) throws -> PendingVisitSubmissionRecord {
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
            overallScore: overallScore,
            ratingTemplate: ratingTemplate,
            sensorySnapshot: sensorySnapshot,
            v3Reflection: v3Reflection,
            taggedCompanions: taggedCompanions,
            posterPhotoIndex: min(max(posterPhotoIndex, 0), max(localNames.count - 1, 0)),
            localPhotoNames: localNames,
            objectPaths: objectPaths,
            createdAt: Date(),
            phase: .prepared,
            uploadedPhotoURLs: nil,
            cafeSession: cafeSession
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

    /// Rebuilds only the durable photo plan while preserving the frozen visit,
    /// session, tasting, rating, and publication payload. The new plan is
    /// persisted before old local files are removed, so a failed rewrite leaves
    /// the prior retry intact.
    func replaceImages(
        for record: PendingVisitSubmissionRecord,
        images: [UIImage],
        posterPhotoIndex: Int
    ) throws -> PendingVisitMediaReplacement {
        guard record.phase < .photosUploaded else {
            throw PendingVisitSubmissionStoreError.mediaAlreadyUploaded
        }

        let visitDirectory = visitDirectory(record.id)
        try fileManager.createDirectory(at: visitDirectory, withIntermediateDirectories: true)
        let planDirectoryName = "plan-\(UUID().uuidString.lowercased())"
        let planDirectory = visitDirectory.appendingPathComponent(
            planDirectoryName,
            isDirectory: true
        )
        let replacementImages = Array(images.prefix(VisitPhotoUploadPlan.maxPhotoCount))
        var localNames: [String] = []

        do {
            if !replacementImages.isEmpty {
                try fileManager.createDirectory(
                    at: planDirectory,
                    withIntermediateDirectories: true
                )
            }
            for (index, image) in replacementImages.enumerated() {
                let fileName = "photo-\(index).jpg"
                guard let data = image
                    .resizedForVisitUpload(maxDimension: 2_000)
                    .jpegData(compressionQuality: 0.82) else {
                    throw PendingVisitSubmissionStoreError.photoEncodingFailed
                }
                try data.write(
                    to: planDirectory.appendingPathComponent(fileName),
                    options: .atomic
                )
                localNames.append("\(planDirectoryName)/\(fileName)")
            }

            var updated = record
            updated.posterPhotoIndex = min(
                max(posterPhotoIndex, 0),
                max(replacementImages.count - 1, 0)
            )
            updated.localPhotoNames = localNames
            updated.objectPaths = VisitPhotoUploadPlan.objectPaths(
                userId: record.userId,
                visitId: record.id,
                objectIds: replacementImages.map { _ in UUID() }
            )
            updated.uploadedPhotoURLs = nil
            try save(updated)

            removeLocalFiles(
                record.localPhotoNames,
                for: record.id,
                preserving: Set(localNames)
            )
            return PendingVisitMediaReplacement(
                record: updated,
                obsoleteObjectPaths: record.phase >= .visitCreated
                    ? record.objectPaths
                    : []
            )
        } catch {
            try? fileManager.removeItem(at: planDirectory)
            throw error
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

    private func removeLocalFiles(
        _ names: [String],
        for visitID: UUID,
        preserving retainedNames: Set<String>
    ) {
        let directory = visitDirectory(visitID)
        for name in names where !retainedNames.contains(name) {
            let fileURL = directory.appendingPathComponent(name)
            try? fileManager.removeItem(at: fileURL)
            let parent = fileURL.deletingLastPathComponent()
            if parent != directory,
               (try? fileManager.contentsOfDirectory(atPath: parent.path).isEmpty) == true {
                try? fileManager.removeItem(at: parent)
            }
        }
    }
}

enum PendingVisitSubmissionStoreError: LocalizedError {
    case photoEncodingFailed
    case missingLocalPhoto
    case mediaAlreadyUploaded
    case submissionIdentityMismatch

    var errorDescription: String? {
        switch self {
        case .photoEncodingFailed:
            return "One selected photo could not be prepared for upload."
        case .missingLocalPhoto:
            return "A saved draft photo is missing. Discard this draft and try again."
        case .mediaAlreadyUploaded:
            return "These photos are already uploaded. Finish the current save before changing them."
        case .submissionIdentityMismatch:
            return "An earlier save belongs to a different sip. It was not submitted from this draft."
        }
    }
}
