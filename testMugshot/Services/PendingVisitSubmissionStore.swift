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
    let homeCoffeeBagID: UUID?
    let brewDetails: BrewDetails?
    let visibility: VisitVisibility
    let ratings: [String: Double]
    let overallScore: Double?
    let ratingTemplate: RatingTemplate
    let sensorySnapshot: SipSensorySnapshot?
    let v3Reflection: V3VisitReflection?
    /// Frozen recipe audience and provenance. Optional keeps upload records
    /// prepared before independent recipe sharing backward decodable.
    let recipePublication: SipRecipePublicationContract?
    /// Ordinary post tags. Tags do not grant shared ownership and do not
    /// require consent. Optional keeps older pending records decodable.
    let taggedCompanions: [SipCompanion]?
    var posterPhotoIndex: Int
    var localPhotoNames: [String]
    var objectPaths: [String]
    let createdAt: Date
    var phase: PendingVisitSubmissionPhase
    var uploadedPhotoURLs: [String]?
    var cafeSession: PendingCafeSessionLink? = nil
    /// Persisted before the first RPC that can make the visit complete. While
    /// this is present without `remoteFinalizedAt`, the server result is
    /// ambiguous and recovery/discard must reconcile it instead of assuming
    /// the publication failed.
    var finalizationRequestedAt: Date? = nil
    /// Durable receipt written immediately after the server has committed the
    /// canonical visit as complete. Once present, recovery may finish audience
    /// and projection work but must never recreate, fail, or discard the visit.
    var remoteFinalizedAt: Date? = nil
    /// Cafe Session audience/attachment is downstream of the visit's atomic
    /// upload-state transition. Keeping its own receipt prevents a completed
    /// visit from being deleted when session publication needs a retry.
    var cafeSessionPublicationCompletedAt: Date? = nil
    /// Written after the frozen V3 reflection has been upserted for the
    /// published visit. A finalized legacy record with a reflection and no
    /// receipt safely retries the idempotent upsert.
    var v3ReflectionCompletedAt: Date? = nil
    /// Written after the independently frozen recipe audience and provenance
    /// have been configured. A nil recipe contract means older records did not
    /// request this action and must not have visibility inferred for them.
    var recipePublicationCompletedAt: Date? = nil
    /// Written only after the ordinary-tag RPC and the outbox save both
    /// succeed. Nil remains retryable for older finalized records.
    var visitTagsCompletedAt: Date? = nil

    var isRemoteFinalized: Bool { remoteFinalizedAt != nil }

    var hasAmbiguousRemoteFinalization: Bool {
        finalizationRequestedAt != nil && !isRemoteFinalized
    }

    var isRemotePublicationProtected: Bool {
        isRemoteFinalized || hasAmbiguousRemoteFinalization
    }

    var needsCafeSessionPublicationCompletion: Bool {
        isRemoteFinalized
            && cafeSession != nil
            && cafeSessionPublicationCompletedAt == nil
    }

    var needsV3ReflectionCompletion: Bool {
        isRemoteFinalized
            && v3Reflection != nil
            && v3ReflectionCompletedAt == nil
    }

    var needsRecipePublicationCompletion: Bool {
        isRemoteFinalized
            && recipePublication != nil
            && recipePublicationCompletedAt == nil
    }

    var needsVisitTagsCompletion: Bool {
        isRemoteFinalized
            && taggedCompanions != nil
            && visitTagsCompletedAt == nil
    }

    var isPostPublicationSetupComplete: Bool {
        isRemoteFinalized
            && !needsCafeSessionPublicationCompletion
            && !needsV3ReflectionCompletion
            && !needsRecipePublicationCompletion
            && !needsVisitTagsCompletion
    }

    /// Compatibility name for call sites compiled against the first identity
    /// receipt model. New code should use `isPostPublicationSetupComplete`.
    var isPostPublicationIdentitySetupComplete: Bool {
        isPostPublicationSetupComplete
    }

    var resolvedEntryContext: JournalEntryContext {
        entryContext ?? .cafe
    }

    var resolvedBrewDetails: BrewDetails {
        brewDetails ?? .empty
    }

    var resolvedRecipePublication: SipRecipePublicationContract {
        recipePublication ?? .privateOriginal
    }

    var includesRecipeBlueprint: Bool {
        resolvedEntryContext == .recipe
            || resolvedBrewDetails.recipeName?.remoteTrimmedNonEmpty != nil
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

enum SipRemoteRecoveryAction: Equatable {
    case retryRemotePublication
    case reconcileRemotePublication
    case finishLocalCompletion
    case accountMismatch
}

enum SipRemoteDiscardPolicy: Equatable {
    case removeLocalOnly
    case verifyRemoteThenDelete
    case preservePublished
}

/// Pure recovery policy used by the composer before it performs any network
/// mutation. Keeping the server receipt in the decision makes retries
/// idempotent even when the app is terminated during the local completion UI.
struct SipRemoteRecoveryPlanner {
    static func action(
        for record: PendingVisitSubmissionRecord,
        authenticatedUserID: UUID
    ) -> SipRemoteRecoveryAction {
        guard record.userId == authenticatedUserID else { return .accountMismatch }
        if record.isRemoteFinalized { return .finishLocalCompletion }
        if record.hasAmbiguousRemoteFinalization {
            return .reconcileRemotePublication
        }
        return .retryRemotePublication
    }

    static func canDestructivelyDiscard(_ record: PendingVisitSubmissionRecord) -> Bool {
        discardPolicy(for: record) == .removeLocalOnly
    }

    static func discardPolicy(
        for record: PendingVisitSubmissionRecord
    ) -> SipRemoteDiscardPolicy {
        if record.isRemoteFinalized { return .preservePublished }
        if record.phase == .prepared && !record.hasAmbiguousRemoteFinalization {
            return .removeLocalOnly
        }
        return .verifyRemoteThenDelete
    }

    static func requiresLocalPhotosForRecovery(
        _ record: PendingVisitSubmissionRecord
    ) -> Bool {
        !record.isRemoteFinalized &&
            record.phase < .photosUploaded &&
            !record.localPhotoNames.isEmpty
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

private struct PendingVisitSubmissionOutbox: Codable {
    static let currentVersion = 2

    let version: Int
    var records: [PendingVisitSubmissionRecord]

    init(records: [PendingVisitSubmissionRecord]) {
        self.version = Self.currentVersion
        self.records = records
    }
}

final class PendingVisitSubmissionStore {
    static let shared = PendingVisitSubmissionStore()

    private static let legacyKeyPrefix = "MugshotPendingVisitSubmission.v1."
    private static let outboxKeyPrefix = "MugshotPendingVisitSubmission.v2."
    private static let migrationKeyPrefix = "MugshotPendingVisitSubmission.v2.migrated."

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let scopedRootDirectory: URL
    private let lock = NSRecursiveLock()

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
        self.scopedRootDirectory = self.baseDirectory.appendingPathComponent("v2", isDirectory: true)
        migrateAllLegacyRecordsBestEffort()
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
        homeCoffeeBagID: UUID? = nil,
        brewDetails: BrewDetails = .empty,
        visibility: VisitVisibility,
        ratings: [String: Double],
        overallScore: Double? = nil,
        ratingTemplate: RatingTemplate,
        sensorySnapshot: SipSensorySnapshot? = nil,
        v3Reflection: V3VisitReflection? = nil,
        recipePublication: SipRecipePublicationContract? = nil,
        taggedCompanions: [SipCompanion]? = nil,
        cafeSession: PendingCafeSessionLink? = nil,
        images: [UIImage],
        posterPhotoIndex: Int
    ) throws -> PendingVisitSubmissionRecord {
        let normalizedCaption = try SipCaptionPolicy.validateAndNormalize(caption)
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyRecordIfNeeded(for: userId)
        guard try readOutbox(for: userId).contains(where: { $0.id == visitId }) == false else {
            throw PendingVisitSubmissionStoreError.submissionIdentityMismatch
        }

        let directory = visitDirectory(visitId, userId: userId)
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
            caption: normalizedCaption,
            notes: notes,
            brewMethod: brewMethod,
            equipment: equipment,
            homeCoffeeBagID: homeCoffeeBagID,
            brewDetails: brewDetails,
            visibility: visibility,
            ratings: ratings,
            overallScore: overallScore,
            ratingTemplate: ratingTemplate,
            sensorySnapshot: sensorySnapshot,
            v3Reflection: v3Reflection,
            recipePublication: recipePublication,
            taggedCompanions: taggedCompanions,
            posterPhotoIndex: min(max(posterPhotoIndex, 0), max(localNames.count - 1, 0)),
            localPhotoNames: localNames,
            objectPaths: objectPaths,
            createdAt: Date(),
            phase: .prepared,
            uploadedPhotoURLs: nil,
            cafeSession: cafeSession
        )
        do {
            try saveWithoutLock(record)
            return record
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    /// Inserts or updates exactly one visit while preserving the rest of the
    /// account's durable outbox.
    func save(_ record: PendingVisitSubmissionRecord) throws {
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyRecordIfNeeded(for: record.userId)
        try saveWithoutLock(record)
    }

    /// Compatibility entry point for single-record recovery screens. Records
    /// are returned oldest first so repeated recovery drains the outbox FIFO.
    func load(userId: UUID) -> PendingVisitSubmissionRecord? {
        (try? loadAll(userId: userId))?.first
    }

    func load(visitId: UUID, userId: UUID) -> PendingVisitSubmissionRecord? {
        (try? loadAll(userId: userId))?.first { $0.id == visitId }
    }

    /// Reads the complete durable outbox for one account. A read or migration
    /// failure is intentionally surfaced: callers must never interpret
    /// unreadable recovery bytes as an empty queue.
    func loadAll(userId: UUID) throws -> [PendingVisitSubmissionRecord] {
        lock.lock()
        defer { lock.unlock() }
        try migrateLegacyRecordIfNeeded(for: userId)
        return try readOutbox(for: userId)
    }

    /// Removes only the durable outbox and media attributable to one account.
    /// Unreadable or cross-account legacy payloads are preserved and reported
    /// instead of guessing ownership and risking another user's recovery data.
    func purge(userId: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        let outboxKey = Self.outboxStorageKey(for: userId)
        let legacyKey = Self.legacyStorageKey(for: userId)
        var attributableVisitIDs: Set<UUID> = []
        var firstError: Error?
        var mayRemoveOutbox = true
        var mayRemoveLegacy = true

        if let data = defaults.data(forKey: outboxKey) {
            let records: [PendingVisitSubmissionRecord]?
            if let outbox = try? JSONDecoder().decode(
                PendingVisitSubmissionOutbox.self,
                from: data
            ), outbox.version == PendingVisitSubmissionOutbox.currentVersion {
                records = outbox.records
            } else {
                records = try? JSONDecoder().decode(
                    [PendingVisitSubmissionRecord].self,
                    from: data
                )
            }
            if let records, records.allSatisfy({ $0.userId == userId }) {
                attributableVisitIDs.formUnion(records.map(\.id))
            } else {
                mayRemoveOutbox = false
                firstError = PendingVisitSubmissionStoreError.outboxUnreadable
            }
        }

        if let data = defaults.data(forKey: legacyKey) {
            if let record = try? JSONDecoder().decode(
                PendingVisitSubmissionRecord.self,
                from: data
            ), record.userId == userId {
                attributableVisitIDs.insert(record.id)
            } else {
                mayRemoveLegacy = false
                firstError = firstError
                    ?? PendingVisitSubmissionStoreError.legacyRecordUnreadable
            }
        }

        let scopedUserDirectory = scopedRootDirectory
            .appendingPathComponent("users", isDirectory: true)
            .appendingPathComponent(userId.uuidString.lowercased(), isDirectory: true)
        let deletionTargets = [scopedUserDirectory]
            + attributableVisitIDs.map(legacyVisitDirectory)
        for target in deletionTargets where fileManager.fileExists(atPath: target.path) {
            do {
                try fileManager.removeItem(at: target)
            } catch {
                firstError = firstError ?? error
            }
        }

        if mayRemoveOutbox { defaults.removeObject(forKey: outboxKey) }
        if mayRemoveLegacy { defaults.removeObject(forKey: legacyKey) }
        defaults.removeObject(forKey: Self.migrationMarkerKey(for: userId))

        if let firstError { throw firstError }
    }

    func loadImages(for record: PendingVisitSubmissionRecord) throws -> [UIImage] {
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyRecordIfNeeded(for: record.userId)
        return try record.localPhotoNames.map { name in
            let url = visitDirectory(record.id, userId: record.userId)
                .appendingPathComponent(name)
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
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyRecordIfNeeded(for: record.userId)
        guard record.phase < .photosUploaded else {
            throw PendingVisitSubmissionStoreError.mediaAlreadyUploaded
        }

        let visitDirectory = visitDirectory(record.id, userId: record.userId)
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
            try saveWithoutLock(updated)

            removeLocalFiles(
                record.localPhotoNames,
                for: record.id,
                userId: record.userId,
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

    /// Removes only the matching visit. A stale, pre-finalization value can
    /// never delete a newer finalized receipt written by another recovery path.
    func remove(_ record: PendingVisitSubmissionRecord) {
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyRecordIfNeeded(for: record.userId)
        guard var records = try? readOutbox(for: record.userId),
              let index = records.firstIndex(where: { $0.id == record.id }) else {
            return
        }
        let storedRecord = records[index]
        guard storedRecord == record else { return }
        records.remove(at: index)
        guard (try? writeOutbox(records, for: record.userId)) != nil else { return }
        try? fileManager.removeItem(
            at: visitDirectory(record.id, userId: record.userId)
        )
    }

    static func legacyStorageKey(for userId: UUID) -> String {
        legacyKeyPrefix + userId.uuidString.lowercased()
    }

    static func outboxStorageKey(for userId: UUID) -> String {
        outboxKeyPrefix + userId.uuidString.lowercased()
    }

    static func migrationMarkerKey(for userId: UUID) -> String {
        migrationKeyPrefix + userId.uuidString.lowercased()
    }

    private func saveWithoutLock(_ record: PendingVisitSubmissionRecord) throws {
        var records = try readOutbox(for: record.userId)
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            let stored = records[index]
            // Once the canonical visit is published, its frozen payload is
            // immutable. Independent recovery workers may hold stale copies,
            // so union durable receipts instead of allowing one success to
            // erase another (or rejecting otherwise useful progress).
            let base = stored.isRemoteFinalized ? stored : record
            records[index] = Self.mergingDurableReceipts(
                into: base,
                from: [stored, record]
            )
        } else {
            records.append(record)
        }
        try writeOutbox(records, for: record.userId)
    }

    private func readOutbox(for userId: UUID) throws -> [PendingVisitSubmissionRecord] {
        guard let data = defaults.data(forKey: Self.outboxStorageKey(for: userId)) else {
            return []
        }
        let records: [PendingVisitSubmissionRecord]
        if let outbox = try? JSONDecoder().decode(PendingVisitSubmissionOutbox.self, from: data),
           outbox.version == PendingVisitSubmissionOutbox.currentVersion {
            records = outbox.records
        } else if let legacyArray = try? JSONDecoder().decode(
            [PendingVisitSubmissionRecord].self,
            from: data
        ) {
            records = legacyArray
        } else {
            throw PendingVisitSubmissionStoreError.outboxUnreadable
        }
        guard records.allSatisfy({ $0.userId == userId }),
              Set(records.map(\.id)).count == records.count else {
            throw PendingVisitSubmissionStoreError.outboxUnreadable
        }
        return Self.ordered(records)
    }

    private func writeOutbox(
        _ records: [PendingVisitSubmissionRecord],
        for userId: UUID
    ) throws {
        guard records.allSatisfy({ $0.userId == userId }),
              Set(records.map(\.id)).count == records.count else {
            throw PendingVisitSubmissionStoreError.outboxUnreadable
        }
        let outbox = PendingVisitSubmissionOutbox(records: Self.ordered(records))
        defaults.set(
            try JSONEncoder().encode(outbox),
            forKey: Self.outboxStorageKey(for: userId)
        )
    }

    private static func ordered(
        _ records: [PendingVisitSubmissionRecord]
    ) -> [PendingVisitSubmissionRecord] {
        records.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func migrateAllLegacyRecordsBestEffort() {
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(Self.legacyKeyPrefix) {
            let suffix = String(key.dropFirst(Self.legacyKeyPrefix.count))
            guard let userId = UUID(uuidString: suffix) else { continue }
            try? migrateLegacyRecordIfNeeded(for: userId)
        }
    }

    private func migrateLegacyRecordIfNeeded(for userId: UUID) throws {
        let markerKey = Self.migrationMarkerKey(for: userId)
        guard !defaults.bool(forKey: markerKey) else { return }
        guard let data = defaults.data(forKey: Self.legacyStorageKey(for: userId)) else {
            defaults.set(true, forKey: markerKey)
            return
        }
        guard let legacyRecord = try? JSONDecoder().decode(
            PendingVisitSubmissionRecord.self,
            from: data
        ), legacyRecord.userId == userId else {
            throw PendingVisitSubmissionStoreError.legacyRecordUnreadable
        }

        var mediaMigrationError: Error?
        do {
            try copyLegacyMediaIfNeeded(for: legacyRecord)
        } catch {
            mediaMigrationError = error
        }
        var records = try readOutbox(for: userId)
        if let index = records.firstIndex(where: { $0.id == legacyRecord.id }) {
            let existing = records[index]
            let preferred: PendingVisitSubmissionRecord
            if legacyRecord.isRemoteFinalized && !existing.isRemoteFinalized {
                preferred = legacyRecord
            } else if existing.isRemoteFinalized == legacyRecord.isRemoteFinalized,
                      legacyRecord.phase > existing.phase {
                preferred = legacyRecord
            } else {
                preferred = existing
            }
            records[index] = Self.mergingDurableReceipts(
                into: preferred,
                from: [existing, legacyRecord]
            )
        } else {
            records.append(legacyRecord)
        }
        try writeOutbox(records, for: userId)
        if let mediaMigrationError { throw mediaMigrationError }
        defaults.set(true, forKey: markerKey)
    }

    private static func mergingDurableReceipts(
        into base: PendingVisitSubmissionRecord,
        from records: [PendingVisitSubmissionRecord]
    ) -> PendingVisitSubmissionRecord {
        var merged = base
        for record in records {
            merged.remoteFinalizedAt = merged.remoteFinalizedAt
                ?? record.remoteFinalizedAt
            merged.finalizationRequestedAt = merged.finalizationRequestedAt
                ?? record.finalizationRequestedAt
            merged.cafeSessionPublicationCompletedAt =
                merged.cafeSessionPublicationCompletedAt
                ?? record.cafeSessionPublicationCompletedAt
            merged.v3ReflectionCompletedAt = merged.v3ReflectionCompletedAt
                ?? record.v3ReflectionCompletedAt
            merged.recipePublicationCompletedAt = merged.recipePublicationCompletedAt
                ?? record.recipePublicationCompletedAt
            merged.visitTagsCompletedAt = merged.visitTagsCompletedAt
                ?? record.visitTagsCompletedAt
        }
        return merged
    }

    private func copyLegacyMediaIfNeeded(
        for record: PendingVisitSubmissionRecord
    ) throws {
        let source = legacyVisitDirectory(record.id)
        guard fileManager.fileExists(atPath: source.path) else { return }
        let destination = visitDirectory(record.id, userId: record.userId)
        if fileManager.fileExists(atPath: destination.path) {
            for name in record.localPhotoNames {
                let sourceFile = source.appendingPathComponent(name)
                let destinationFile = destination.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: sourceFile.path),
                      !fileManager.fileExists(atPath: destinationFile.path) else {
                    continue
                }
                let parent = destinationFile.deletingLastPathComponent()
                try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                try fileManager.copyItem(at: sourceFile, to: destinationFile)
            }
            return
        }

        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(
            ".migration-\(UUID().uuidString.lowercased())",
            isDirectory: true
        )
        do {
            try fileManager.copyItem(at: source, to: staging)
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func visitDirectory(_ visitId: UUID, userId: UUID) -> URL {
        scopedRootDirectory
            .appendingPathComponent("users", isDirectory: true)
            .appendingPathComponent(userId.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(visitId.uuidString.lowercased(), isDirectory: true)
    }

    private func legacyVisitDirectory(_ visitId: UUID) -> URL {
        baseDirectory.appendingPathComponent(visitId.uuidString.lowercased(), isDirectory: true)
    }

    private func removeLocalFiles(
        _ names: [String],
        for visitID: UUID,
        userId: UUID,
        preserving retainedNames: Set<String>
    ) {
        let directory = visitDirectory(visitID, userId: userId)
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
    case finalizedReceiptConflict
    case legacyRecordUnreadable
    case outboxUnreadable

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
        case .finalizedReceiptConflict:
            return "This Mugshot is already published. Its recovery receipt was left unchanged."
        case .legacyRecordUnreadable:
            return "Mugshot could not migrate an earlier saved upload. The original was left unchanged."
        case .outboxUnreadable:
            return "Mugshot could not read the saved upload queue. Its contents were left unchanged."
        }
    }
}
