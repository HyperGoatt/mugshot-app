import Foundation
import Supabase

@MainActor
final class VisitEditService {
    private let client: SupabaseClient
    private let visitService: VisitService
    private let photoService: VisitPhotoUploadService
    private let cleanupStore: VisitMediaCleanupStore

    init(
        client: SupabaseClient,
        cleanupStore: VisitMediaCleanupStore = .shared
    ) {
        self.client = client
        visitService = VisitService(client: client)
        photoService = VisitPhotoUploadService(client: client)
        self.cleanupStore = cleanupStore
    }

    func save(
        detail: RemoteVisitDetail,
        currentUserID: UUID,
        draft sourceDraft: SipPostEditDraft
    ) async throws -> RemoteVisitDetail? {
        guard detail.summary.visit.userId == currentUserID else {
            throw SipPostEditValidationError.notOwner
        }

        var draft = sourceDraft
        SipPostEditPolicy.moveCoverFirst(in: &draft)
        let values = try SipPostEditPolicy.normalize(
            draft,
            context: detail.summary.visit.journalContext,
            hasV3Reflection: detail.v3Reflection != nil
        )

        let addedPhotos = draft.photos.compactMap(\.addedImage)
        let uploaded = try await photoService.uploadPhotos(
            userId: currentUserID,
            visitId: detail.id,
            images: addedPhotos,
            posterPhotoIndex: 0
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
        let newLocations = uploaded.attachmentReferences.compactMap(
            VisitPhotoStorageLocation.init(storedValue:)
        )

        do {
            try await client.rpc(
                "edit_owned_visit_v1",
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
                    photoURLs: orderedPhotoReferences
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

                if !newLocations.isEmpty {
                    try? await photoService.deletePhotos(at: newLocations)
                }
            } catch {
                // The write outcome is ambiguous. Keep uploaded objects because
                // deleting one that the committed row references would break a
                // published Mugshot. A later edit/delete can safely reconcile it.
            }
            throw rpcError
        }

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
              criteriaMatch(summary.visit.orderedRatingScores, values.sipCriteria) else {
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
