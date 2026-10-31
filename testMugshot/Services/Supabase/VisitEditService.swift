import Foundation
import Supabase

@MainActor
final class VisitEditService {
    private let client: SupabaseClient
    private let visitService: VisitService
    private let photoService: VisitPhotoUploadService
    private let cleanupStore: VisitMediaCleanupStore
    private let progressStore: VisitEditMediaProgressStore

    init(
        client: SupabaseClient,
        cleanupStore: VisitMediaCleanupStore = .shared,
        progressStore: VisitEditMediaProgressStore = .shared
    ) {
        self.client = client
        visitService = VisitService(client: client)
        photoService = VisitPhotoUploadService(client: client)
        self.cleanupStore = cleanupStore
        self.progressStore = progressStore
    }

    func save(
        detail: RemoteVisitDetail,
        currentUserID: UUID,
        draft sourceDraft: SipPostEditDraft
    ) async throws -> RemoteVisitDetail? {
        try Task.checkCancellation()
        guard client.auth.currentUser?.id == currentUserID,
              detail.summary.visit.userId == currentUserID else {
            throw SipPostEditValidationError.notOwner
        }

        guard let token = SipPublicationGate.shared.begin(userID: currentUserID, visitID: detail.id) else {
            throw VisitServiceError.accountScopeChanged
        }
        defer { SipPublicationGate.shared.finish(token: token) }
        var draft = sourceDraft
        SipPostEditPolicy.moveCoverFirst(in: &draft)
        let values = try SipPostEditPolicy.normalize(
            draft,
            context: detail.summary.visit.journalContext,
            hasV3Reflection: detail.v3Reflection != nil
        )

        let added = draft.photos.filter { $0.addedImage != nil }
        let addedPhotos = added.compactMap(\.addedImage)
        let paths = try added.map { photo in
            guard photo.id.hasPrefix("added-"),
                  let objectID = UUID(uuidString: String(photo.id.dropFirst(6))) else {
                throw VisitPhotoUploadError.invalidUploadPlan
            }
            return VisitPhotoUploadPlan.objectPath(userId: currentUserID, visitId: detail.id, objectId: objectID)
        }
        let uploaded = try await photoService.uploadPhotos(
            userId: currentUserID,
            visitId: detail.id,
            images: addedPhotos,
            posterPhotoIndex: 0,
            plannedObjectPaths: paths,
            replacingExisting: true,
            completedObjectPaths: progressStore.completedPaths(userID: currentUserID, visitID: detail.id, plannedPaths: paths),
            onPhotoUploaded: { path in
                try self.progressStore.record(path, userID: currentUserID, visitID: detail.id, plannedPaths: paths)
            }
        )
        let uploadedByID = Dictionary(
            uniqueKeysWithValues: zip(
                draft.photos.filter { $0.addedImage != nil }.map(\.id),
                uploaded.attachmentReferences
            )
        )
        let orderedPhotoReferences = draft.photos.compactMap { photo in
            photo.existingStoredValue ?? uploadedByID[photo.id]
        }
        do {
            try Task.checkCancellation()
            guard client.auth.currentUser?.id == currentUserID else {
                throw SipPostEditValidationError.notOwner
            }
            try await client.rpc(
                "edit_owned_visit_v2",
                params: EditOwnedVisitParameters(
                    visitID: detail.id,
                    caption: values.caption,
                    visibility: values.postAudience.supabaseValue,
                    overallScore: values.sipScore,
                    sipCriteria: values.sipCriteria,
                    contextScore: values.contextScore,
                    contextCriteria: values.contextCriteria,
                    sipRawNote: values.sipJournalNote,
                    contextRawNote: values.contextJournalNote,
                    rawNoteVisibility: values.journalAudience.supabaseValue,
                    legacyPrivateNote: values.legacyPrivateJournalNote,
                    photoURLs: orderedPhotoReferences,
                    taggedUserIDs: values.taggedUserIDs
                )
            )
            .execute()
        } catch let rpcError {
            do {
                if try await canonicalEditMatches(
                    detail: detail,
                    currentUserID: currentUserID,
                    values: values,
                    orderedPhotoReferences: orderedPhotoReferences
                ) {
                    finishMediaProgress(currentUserID: currentUserID, visitID: detail.id, retaining: Set(orderedPhotoReferences))
                    await removeDetachedMedia(
                        from: detail,
                        retaining: Set(orderedPhotoReferences),
                        currentUserID: currentUserID
                    )
                    return try? await visitService.fetchVisitDetail(
                        visitId: detail.id,
                        currentUserId: currentUserID
                    )
                }

                // Keep acknowledged objects for this exact edit's stable photo
                // IDs. A later retry must not re-upload successful photos.
            } catch {
                // The write outcome is ambiguous. Keep uploaded objects because
                // deleting one that the committed row references would break a
                // published Mugshot. A later edit/delete can safely reconcile it.
            }
            throw rpcError
        }

        finishMediaProgress(currentUserID: currentUserID, visitID: detail.id, retaining: Set(orderedPhotoReferences))
        await removeDetachedMedia(
            from: detail,
            retaining: Set(orderedPhotoReferences),
            currentUserID: currentUserID
        )

        return try? await visitService.fetchVisitDetail(
            visitId: detail.id,
            currentUserId: currentUserID
        )
    }

    private func finishMediaProgress(currentUserID: UUID, visitID: UUID, retaining references: Set<String>) {
        let obsolete = progressStore.allPaths(userID: currentUserID, visitID: visitID)
            .compactMap { path -> VisitPhotoStorageLocation? in
                let location = VisitPhotoStorageLocation(bucketName: VisitPhotoStorageReference.privateBucketName, objectPath: path)
                return references.contains(location.cleanupIdentifier) ? nil : location
            }
        // Only a confirmed canonical commit makes abandoned edit objects safe
        // for the existing durable cleanup queue. Ambiguous responses retain them.
        if !obsolete.isEmpty { cleanupStore.enqueue(obsolete, userId: currentUserID) }
        progressStore.remove(userID: currentUserID, visitID: visitID)
    }

    private func canonicalEditMatches(
        detail: RemoteVisitDetail,
        currentUserID: UUID,
        values: SipPostEditNormalizedValues,
        orderedPhotoReferences: [String]
    ) async throws -> Bool {
        let summary = try await visitService.fetchOwnedVisitSummary(
            visitId: detail.id,
            userId: currentUserID
        )
        let photoRows = try await visitService.fetchVisitPhotoRows(visitId: detail.id)
        let orderedPhotos = photoRows.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder { return lhs.createdAt < rhs.createdAt }
            return lhs.sortOrder < rhs.sortOrder
        }.map(\.photoURL)

        guard summary.visit.caption == values.caption,
              VisitVisibility.supabaseValue(summary.visit.visibility) == values.postAudience,
              summary.visit.overallScore == values.sipScore,
              summary.visit.posterPhotoURL == orderedPhotoReferences.first,
              orderedPhotos == orderedPhotoReferences,
              criteriaMatch(summary.visit.orderedRatingScores, values.sipCriteria),
              try await canonicalTagIDs(for: detail.id) == Set(values.taggedUserIDs) else {
            return false
        }

        if detail.v3Reflection != nil {
            guard let reflection = try await V3VisitReflectionService(client: client)
                .fetchVisible(visitID: detail.id) else { return false }
            return reflection.sipScore == values.sipScore
                && reflection.contextScore == values.contextScore
                && reflection.rawNoteVisibility == values.journalAudience
                && reflection.sipRawNote == values.sipJournalNote
                && reflection.contextRawNote == values.contextJournalNote
                && criteriaMatch(reflection.contextCriteria, values.contextCriteria)
        }

        let privateNote = try await visitService.fetchPrivateNote(
            visitId: detail.id,
            userId: currentUserID
        )
        return privateNote == values.legacyPrivateJournalNote
    }

    private func canonicalTagIDs(for visitID: UUID) async throws -> Set<UUID> {
        let tags: [RemoteVisitTag] = try await client.rpc(
            "list_visible_visit_tags_v1",
            params: ["p_visit_id": visitID]
        ).execute().value
        return Set(tags.map(\.userID))
    }

    private func criteriaMatch(
        _ stored: [SupabaseVisitCategoryScore],
        _ expected: [SipRatingCriterionSnapshot]
    ) -> Bool {
        guard stored.count == expected.count else { return false }
        return zip(stored, expected).allSatisfy { stored, expected in
            stored.name == expected.name
                && stored.score == expected.score
                && stored.weight == expected.weight
        }
    }

    private func criteriaMatch(
        _ stored: [SipRatingCriterionSnapshot],
        _ expected: [SipRatingCriterionSnapshot]
    ) -> Bool {
        guard stored.count == expected.count else { return false }
        return zip(stored, expected).allSatisfy { stored, expected in
            stored.id == expected.id
                && stored.name == expected.name
                && stored.score == expected.score
                && stored.weight == expected.weight
                && stored.sortOrder == expected.sortOrder
        }
    }

    private func removeDetachedMedia(
        from detail: RemoteVisitDetail,
        retaining retainedReferences: Set<String>,
        currentUserID: UUID
    ) async {
        let oldReferences = Set(
            detail.photos.map(\.photoURL)
                + [detail.summary.visit.posterPhotoURL].compactMap { $0 }
        )
        let ownerPrefix = currentUserID.uuidString.lowercased() + "/"
        let locations = oldReferences
            .subtracting(retainedReferences)
            .compactMap(VisitPhotoStorageLocation.init(storedValue:))
            .filter { $0.objectPath.lowercased().hasPrefix(ownerPrefix) }
        guard !locations.isEmpty else { return }

        do {
            try await photoService.deletePhotos(at: locations)
            cleanupStore.remove(locations, userId: currentUserID)
        } catch {
            cleanupStore.enqueue(locations, userId: currentUserID)
        }
    }
}

private struct EditOwnedVisitParameters: Encodable {
    let visitID: UUID
    let caption: String
    let visibility: String
    let overallScore: Double
    let sipCriteria: [SipRatingCriterionSnapshot]
    let contextScore: Double?
    let contextCriteria: [SipRatingCriterionSnapshot]
    let sipRawNote: String?
    let contextRawNote: String?
    let rawNoteVisibility: String
    let legacyPrivateNote: String?
    let photoURLs: [String]
    let taggedUserIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case visitID = "p_visit_id"
        case caption = "p_caption"
        case visibility = "p_visibility"
        case overallScore = "p_overall_score"
        case sipCriteria = "p_sip_criteria"
        case contextScore = "p_context_score"
        case contextCriteria = "p_context_criteria"
        case sipRawNote = "p_sip_raw_note"
        case contextRawNote = "p_context_raw_note"
        case rawNoteVisibility = "p_raw_note_visibility"
        case legacyPrivateNote = "p_legacy_private_note"
        case photoURLs = "p_photo_urls"
        case taggedUserIDs = "p_tagged_user_ids"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(visitID, forKey: .visitID)
        try container.encode(caption, forKey: .caption)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encode(sipCriteria, forKey: .sipCriteria)
        try container.encode(contextCriteria, forKey: .contextCriteria)
        try container.encode(rawNoteVisibility, forKey: .rawNoteVisibility)
        try container.encode(photoURLs, forKey: .photoURLs)
        try container.encode(taggedUserIDs, forKey: .taggedUserIDs)
        try container.encodeIfPresent(contextScore, forKey: .contextScore)
        if contextScore == nil { try container.encodeNil(forKey: .contextScore) }
        try container.encodeIfPresent(sipRawNote, forKey: .sipRawNote)
        if sipRawNote == nil { try container.encodeNil(forKey: .sipRawNote) }
        try container.encodeIfPresent(contextRawNote, forKey: .contextRawNote)
        if contextRawNote == nil { try container.encodeNil(forKey: .contextRawNote) }
        try container.encodeIfPresent(legacyPrivateNote, forKey: .legacyPrivateNote)
        if legacyPrivateNote == nil { try container.encodeNil(forKey: .legacyPrivateNote) }
    }
}
