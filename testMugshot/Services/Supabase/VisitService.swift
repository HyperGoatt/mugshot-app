//
//  VisitService.swift
//  testMugshot
//

import CoreLocation
import Foundation
import Supabase

final class VisitService {
    private let client: SupabaseClient
    private let cafeService: CafeService
    private let profileService: ProfileService

    private let visitColumns = """
    id, user_id, cafe_id, drink_type, drink_type_custom, drink_subtype, caption, visibility, upload_state, ratings, category_scores, overall_score, poster_photo_url, context_type, location_name, city_state, home_coffee_bag_id, recipe_version_id, cafe_session_id, cafe_session_order, cafe_session_role, created_at
    """

    private let legacyVisitColumns = """
    id, user_id, cafe_id, drink_type, drink_type_custom, drink_subtype, caption, visibility, upload_state, ratings, category_scores, overall_score, poster_photo_url, context_type, location_name, city_state, recipe_version_id, created_at
    """

    private let photoColumns = """
    id, visit_id, photo_url, sort_order, created_at
    """

    private let likeColumns = """
    id, user_id, visit_id, created_at
    """

    private let reactionLikeColumns = """
    id, user_id, visit_id, created_at, reaction_kind
    """

    private let commentColumns = """
    id, user_id, visit_id, text, created_at, parent_comment_id
    """

    init(
        client: SupabaseClient,
        cafeService: CafeService? = nil,
        profileService: ProfileService? = nil
    ) {
        self.client = client
        self.cafeService = cafeService ?? CafeService(client: client)
        self.profileService = profileService ?? ProfileService(client: client)
    }

    func fetchRecentVisits(
        userId: UUID,
        limit: Int = 10,
        includeSocialState: Bool = false
    ) async throws -> [RemoteVisitSummary] {
        let rows: [SupabaseVisitRow] = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .select(columns)
                .eq("user_id", value: userId.uuidString)
                .eq("upload_state", value: VisitUploadState.complete.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }

        return try await hydrate(
            rows: rows,
            includeAuthors: false,
            currentUserId: userId,
            includeSocialState: includeSocialState
        )
    }

    func fetchOwnerBrewDetails(
        visitIDs: [UUID]? = nil,
        limit: Int = 500
    ) async throws -> [OwnerVisitBrewRow] {
        let boundedLimit = min(max(limit, 1), 500)
        let parameters = OwnerVisitBrewDetailsParameters(
            visitIDs: visitIDs,
            limit: boundedLimit
        )
        do {
            return try await client.rpc(
                "get_owner_visit_brew_details_v1",
                params: parameters
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            // The Journal can still render its safe visit summaries during a
            // staggered app/backend rollout; private brew enrichment resumes
            // automatically once the owner-bound RPC is available.
            return []
        }
    }

    func fetchOwnerSipCount(userId: UUID) async throws -> Int {
        let response = try await client
            .from("visits")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .eq("upload_state", value: VisitUploadState.complete.rawValue)
            .execute()
        return response.count ?? 0
    }

    func fetchCafeVisits(
        cafeId: UUID,
        userId: UUID,
        limit: Int = 10
    ) async throws -> [RemoteVisitSummary] {
        try await fetchCafeVisits(
            cafeIds: [cafeId],
            userId: userId,
            limit: limit
        )
    }

    func fetchCafeVisits(
        cafeIds: some Collection<UUID>,
        userId: UUID,
        limit: Int = 10
    ) async throws -> [RemoteVisitSummary] {
        let identifiers = Array(Set(cafeIds))
        guard !identifiers.isEmpty else { return [] }
        let rows: [SupabaseVisitRow] = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .select(columns)
                .in("cafe_id", values: identifiers.map(\.uuidString))
                .eq("user_id", value: userId.uuidString)
                .or("context_type.eq.Cafe,context_type.is.null")
                .eq("upload_state", value: VisitUploadState.complete.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }

        return try await hydrate(rows: rows, includeAuthors: false)
    }

    func fetchVisibleCafeVisits(
        cafeId: UUID,
        currentUserId: UUID?,
        limit: Int = 20
    ) async throws -> [RemoteVisitSummary] {
        try await fetchVisibleCafeVisits(
            cafeIds: [cafeId],
            currentUserId: currentUserId,
            limit: limit
        )
    }

    func fetchVisibleCafeVisits(
        cafeIds: some Collection<UUID>,
        currentUserId: UUID?,
        limit: Int = 20
    ) async throws -> [RemoteVisitSummary] {
        let identifiers = Array(Set(cafeIds))
        guard !identifiers.isEmpty else { return [] }
        let rows: [SupabaseVisitRow] = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .select(columns)
                .in("cafe_id", values: identifiers.map(\.uuidString))
                .or("context_type.eq.Cafe,context_type.is.null")
                .eq("upload_state", value: VisitUploadState.complete.rawValue)
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(limit)
                .execute()
                .value
        }

        return try await hydrate(
            rows: rows,
            includeAuthors: true,
            currentUserId: currentUserId,
            includeSocialState: true
        )
    }

    func fetchMapVisitSeeds(userId: UUID) async throws -> [RemoteMapVisitSeed] {
        let rows: [MapVisitRow] = try await withCafeSessionSchemaFallback { hasCafeSessions in
            try await client
                .from("visits")
                .select(
                    hasCafeSessions
                        ? "cafe_id, overall_score, context_type, cafe_session_id, created_at, poster_photo_url"
                        : "cafe_id, overall_score, context_type, created_at, poster_photo_url"
                )
                .eq("user_id", value: userId.uuidString)
                .eq("upload_state", value: VisitUploadState.complete.rawValue)
                .not("cafe_id", operator: .is, value: "null")
                .execute()
                .value
        }
        let cafes = try await cafeService.fetchCafes(ids: rows.compactMap { row in
            JournalEntryContext(backendValue: row.contextType) == .cafe
                ? row.cafeId
                : nil
        })
        let cafesByID = Dictionary(uniqueKeysWithValues: cafes.map { ($0.id, $0) })
        return rows.compactMap { row in
            guard JournalEntryContext(backendValue: row.contextType) == .cafe,
                  let cafeId = row.cafeId,
                  let cafe = cafesByID[cafeId] else { return nil }
            return RemoteMapVisitSeed(
                cafe: cafe,
                overallScore: row.overallScore,
                cafeSessionID: row.cafeSessionID,
                createdAt: MapVisitDateParser.date(from: row.createdAt) ?? .distantPast,
                posterPhotoURL: row.posterPhotoURL?.remoteTrimmedNonEmpty
            )
        }
    }

    func fetchFeedVisits(
        scope: FeedScope,
        currentUserId: UUID?,
        limit: Int = 12,
        before cursor: RemoteFeedCursor? = nil,
        location: CLLocation? = nil
    ) async throws -> [RemoteVisitSummary] {
        return try await fetchRankedFeedVisits(
            scope: scope,
            currentUserId: currentUserId,
            limit: limit,
            before: cursor,
            location: location
        )
    }

    private func fetchRankedFeedVisits(
        scope: FeedScope,
        currentUserId: UUID?,
        limit: Int,
        before cursor: RemoteFeedCursor?,
        location: CLLocation?
    ) async throws -> [RemoteVisitSummary] {
        let references: [RankedFeedReference] = try await client.rpc(
            "ranked_feed",
            params: RankedFeedParameters(
                pScope: scope.rpcValue,
                pLatitude: location?.coordinate.latitude,
                pLongitude: location?.coordinate.longitude,
                pLimit: limit,
                pAfterScore: cursor?.rankingScore,
                pAfterCreatedAt: cursor?.createdAt,
                pAfterID: cursor?.id
            )
        ).execute().value
        guard !references.isEmpty else { return [] }

        let rows: [SupabaseVisitRow] = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .select(columns)
                .in("id", values: references.map { $0.visitID.uuidString })
                .execute()
                .value
        }
        let summaries = try await hydrate(
            rows: rows,
            includeAuthors: true,
            currentUserId: currentUserId,
            includeSocialState: true
        )
        let summariesByID = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        return references.compactMap { reference in
            guard let summary = summariesByID[reference.visitID],
                  summary.visit.isCafeSessionPrimary else {
                return nil
            }
            return RemoteVisitSummary(
                visit: summary.visit,
                cafe: summary.cafe,
                author: summary.author,
                socialState: summary.socialState,
                rankingScore: reference.feedScore,
                recommendationReason: reference.rankingReason,
                recommendationReasonType: reference.reasonType,
                sessionSipCount: summary.sessionSipCount,
                cafePulseProjection: summary.cafePulseProjection,
                v3FeedProjection: summary.v3FeedProjection
            )
        }
    }

    func fetchVisitDetail(
        visitId: UUID,
        currentUserId: UUID?
    ) async throws -> RemoteVisitDetail {
        let rows: [SupabaseVisitRow] = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .select(columns)
                .eq("id", value: visitId.uuidString)
                .limit(1)
                .execute()
                .value
        }

        guard let baseRow = rows.first else {
            throw VisitServiceError.visitNotFound
        }

        let row: SupabaseVisitRow
        if currentUserId == baseRow.userId {
            let ownerRows = try await fetchOwnerBrewDetails(
                visitIDs: [visitId],
                limit: 1
            )
            if let ownerBrew = ownerRows.first {
                row = baseRow.attachingOwnerBrewDetails(
                    brewMethod: ownerBrew.brewMethod,
                    equipment: ownerBrew.equipment,
                    brewDetails: ownerBrew.brewDetails
                )
            } else {
                row = baseRow
            }
        } else {
            row = baseRow
        }

        async let summariesRequest = hydrate(rows: [row], includeAuthors: true)
        async let photosRequest: [SupabaseVisitPhotoRow] = client
            .from("visit_photos")
            .select(photoColumns)
            .eq("visit_id", value: visitId.uuidString)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
        async let likesRequest = fetchLikes(visitId: visitId)
        async let commentsRequest = fetchComments(visitId: visitId)
        async let cafeSessionSummaryRequest = fetchCafeSessionSummaryIfPresent(
            sessionID: row.journalContext == .cafe ? row.cafeSessionID : nil
        )
        async let v3ReflectionRequest: V3VisitReflection? = {
            try? await V3VisitReflectionService(client: client).fetchVisible(visitID: visitId)
        }()
        async let recipeProjectionRequest: RemoteVisitRecipeProjection? = {
            guard currentUserId != nil, row.recipeVersionID != nil else { return nil }
            do {
                return try await fetchRecipeProjection(visitId: visitId)
            } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                return nil
            }
        }()
        async let recipeIdentityProjectionRequest: RemoteVisitRecipeIdentityProjection? = {
            guard currentUserId != nil, row.recipeVersionID != nil else { return nil }
            do {
                return try await fetchRecipeIdentityProjection(visitId: visitId)
            } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                return nil
            }
        }()
        async let taggedAccountsRequest: [RemoteVisitTag] = {
            guard currentUserId != nil else { return [] }
            do {
                return try await fetchVisibleVisitTags(visitId: visitId)
            } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                return []
            }
        }()

        let (
            summaries,
            photos,
            likes,
            comments,
            cafeSessionSummary,
            v3Reflection,
            recipeProjection,
            recipeIdentityProjection,
            taggedAccounts
        ) = try await (
            summariesRequest,
            photosRequest,
            likesRequest,
            commentsRequest,
            cafeSessionSummaryRequest,
            v3ReflectionRequest,
            recipeProjectionRequest,
            recipeIdentityProjectionRequest,
            taggedAccountsRequest
        )
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }

        let privateNote: String?
        let sensorySnapshot: SipSensorySnapshot?
        if currentUserId == row.userId {
            privateNote = try await fetchPrivateNote(visitId: visitId, userId: row.userId)
            sensorySnapshot = try await SensorySnapshotService(client: client).fetchSnapshot(
                visitID: visitId,
                userID: row.userId
            )
        } else {
            privateNote = nil
            sensorySnapshot = nil
        }

        return RemoteVisitDetail(
            summary: summary,
            photos: photos,
            comments: comments,
            likeCount: likes.count,
            currentUserHasLiked: currentUserId.map { userId in
                likes.contains { $0.userId == userId }
            } ?? false,
            privateNote: privateNote,
            sensorySnapshot: sensorySnapshot,
            cafeSessionSummary: cafeSessionSummary,
            v3Reflection: v3Reflection,
            recipeProjection: recipeProjection,
            recipeIdentityProjection: recipeIdentityProjection,
            taggedAccounts: taggedAccounts
        )
    }

    func fetchRecipeProjection(
        visitId: UUID
    ) async throws -> RemoteVisitRecipeProjection? {
        try await client.rpc(
            "get_recipe_projection_for_visit_v1",
            params: ["p_visit_id": visitId]
        ).execute().value
    }

    func fetchRecipeProjection(
        recipeVersionId: UUID
    ) async throws -> RemoteVisitRecipeProjection? {
        try await client.rpc(
            "get_recipe_projection_v1",
            params: ["p_recipe_version_id": recipeVersionId]
        ).execute().value
    }

    func fetchRecipeIdentityProjection(
        visitId: UUID
    ) async throws -> RemoteVisitRecipeIdentityProjection? {
        let rows: [RemoteVisitRecipeIdentityProjection] = try await client.rpc(
            "get_recipe_identity_for_visit_v1",
            params: ["p_visit_id": visitId]
        ).execute().value
        return rows.first
    }

    func fetchVisibleVisitTags(visitId: UUID) async throws -> [RemoteVisitTag] {
        try await client.rpc(
            "list_visible_visit_tags_v1",
            params: ["p_visit_id": visitId]
        ).execute().value
    }

    private func fetchCafeSessionSummaryIfPresent(
        sessionID: UUID?
    ) async throws -> RemoteCafeSessionSummary? {
        guard let sessionID else { return nil }
        return try await CafeSessionService(client: client)
            .fetchSessionSummary(sessionID: sessionID)
    }

    func fetchPrivateNote(visitId: UUID, userId: UUID) async throws -> String? {
        let rows: [SupabaseVisitPrivateNoteRow] = try await client
            .from("visit_private_notes")
            .select("visit_id, user_id, note")
            .eq("visit_id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.note.remoteTrimmedNonEmpty
    }

    func updatePrivateNote(visitId: UUID, userId: UUID, note: String?) async throws {
        guard let note = note?.remoteTrimmedNonEmpty else {
            try await client
                .from("visit_private_notes")
                .delete()
                .eq("visit_id", value: visitId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            return
        }

        try await client
            .from("visit_private_notes")
            .upsert(
                SupabaseVisitPrivateNoteUpsert(visitId: visitId, userId: userId, note: note),
                onConflict: "visit_id"
            )
            .execute()
    }

    func fetchSocialState(
        visitId: UUID,
        currentUserId: UUID?
    ) async throws -> RemoteVisitSocialState {
        let likes = try await fetchLikes(visitId: visitId)

        let comments: [SupabaseVisitCommentRow] = try await client
            .from("comments")
            .select(commentColumns)
            .eq("visit_id", value: visitId.uuidString)
            .execute()
            .value

        return makeSocialState(
            likes: likes,
            commentCount: comments.count,
            currentUserId: currentUserId
        )
    }

    func setReaction(
        visitId: UUID,
        userId: UUID,
        reaction: PostReactionKind?
    ) async throws -> VisitReactionState {
        do {
            let states: [VisitReactionState] = try await client.rpc(
                "set_visit_reaction_v1",
                params: SetVisitReactionParameters(
                    pVisitID: visitId,
                    pReactionKind: reaction?.rawValue
                )
            ).execute().value
            guard let state = states.first else {
                throw VisitServiceError.visitNotFound
            }
            return state
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            guard reaction == nil || reaction == .like else {
                throw VisitServiceError.expressiveReactionsUnavailable
            }

            if reaction == nil {
                try await client
                    .from("likes")
                    .delete()
                    .eq("visit_id", value: visitId.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } else {
                try await client
                    .from("likes")
                    .upsert(
                        SupabaseVisitLikeInsert(userId: userId, visitId: visitId),
                        onConflict: "user_id,visit_id"
                    )
                    .execute()
            }

            let likes = try await fetchLikes(visitId: visitId)
            return reactionState(from: likes, currentUserId: userId)
        }
    }

    func toggleLike(
        visitId: UUID,
        userId: UUID,
        currentlyLiked: Bool
    ) async throws -> RemoteVisitSocialState {
        _ = try await setReaction(
            visitId: visitId,
            userId: userId,
            reaction: currentlyLiked ? nil : .like
        )

        return try await fetchSocialState(
            visitId: visitId,
            currentUserId: userId
        )
    }

    func addComment(
        visitId: UUID,
        userId: UUID,
        text: String,
        parentCommentId: UUID? = nil,
        mentions: [CommentMentionSelection] = []
    ) async throws -> RemoteVisitSocialState {
        guard let trimmedText = text.remoteTrimmedNonEmpty else {
            throw VisitServiceError.emptyComment
        }

        let parameters = CreateCommentV2Parameters(
            pVisitId: visitId,
            pText: trimmedText,
            pParentCommentId: parentCommentId,
            pMentions: mentions
        )
        do {
            try await client.rpc("create_comment_v2", params: parameters).execute()
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            try await client.rpc(
                "create_comment",
                params: CreateCommentLegacyParameters(
                    pVisitId: visitId,
                    pText: trimmedText,
                    pParentCommentId: parentCommentId,
                    pMentionedUserIds: mentions.map(\.userID)
                )
            ).execute()
        }

        return try await fetchSocialState(
            visitId: visitId,
            currentUserId: userId
        )
    }

    func updateComment(commentID: UUID, text: String) async throws {
        guard let trimmedText = text.remoteTrimmedNonEmpty else {
            throw VisitServiceError.emptyComment
        }
        try await client.rpc(
            "update_comment_v1",
            params: UpdateCommentParameters(
                pCommentID: commentID,
                pText: trimmedText
            )
        ).execute()
    }

    /// Soft-removes the comment through the caller-bound RPC. The next detail
    /// reload is the source of truth and omits the tombstoned comment/thread.
    func removeComment(
        commentID: UUID,
        reason: String = "removed_by_user"
    ) async throws {
        try await client.rpc(
            "remove_comment_v1",
            params: RemoveCommentParameters(
                pCommentID: commentID,
                pReason: reason
            )
        ).execute()
    }

    func updateVisit(
        visitId: UUID,
        userId: UUID,
        update: SupabaseVisitUpdate
    ) async throws -> RemoteVisitSummary {
        let row: SupabaseVisitRow = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .update(update)
                .eq("id", value: visitId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .select(columns)
                .single()
                .execute()
                .value
        }

        let summaries = try await hydrate(
            rows: [row],
            includeAuthors: true,
            currentUserId: userId,
            includeSocialState: true
        )
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }

        return summary
    }

    func deleteVisit(
        visitId: UUID,
        userId: UUID
    ) async throws {
        try await client
            .from("visits")
            .delete()
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Deletes one visit through an owner-bound backend transaction and
    /// returns the media references that are now safe to remove from Storage.
    func deleteOwnedVisit(visitId: UUID) async throws -> [String] {
        let rows: [DeletedOwnedVisitPhotoRow] = try await client
            .rpc(
                "delete_owned_visit_v1",
                params: DeleteOwnedVisitParameters(pVisitID: visitId)
            )
            .execute()
            .value
        return rows.map(\.photoURL)
    }

    /// Returns only the owner-visible upload state so recovery can reconcile
    /// an ambiguous publication without hydrating any secondary resources.
    func fetchOwnedVisitUploadState(
        visitId: UUID,
        userId: UUID
    ) async throws -> VisitUploadState? {
        let rows: [SupabaseOwnedVisitUploadStateRow] = try await client
            .from("visits")
            .select("id, upload_state")
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        guard let state = VisitUploadState(rawValue: row.uploadState) else {
            throw VisitServiceError.invalidUploadState(row.uploadState)
        }
        return state
    }

    /// Deletes only a row that is still incomplete. The upload-state filter
    /// closes the race between a discard reconciliation read and a concurrent
    /// successful publication. Callers must fetch again and confirm absence
    /// before removing the local recovery record.
    func deleteOwnedIncompleteVisit(
        visitId: UUID,
        userId: UUID
    ) async throws {
        try await client
            .from("visits")
            .delete()
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .neq("upload_state", value: VisitUploadState.complete.rawValue)
            .execute()
    }

    func fetchVisitPhotoRows(visitId: UUID) async throws -> [SupabaseVisitPhotoRow] {
        try await client
            .from("visit_photos")
            .select(photoColumns)
            .eq("visit_id", value: visitId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func createVisit(
        visitId: UUID = UUID(),
        userId: UUID,
        cafe: Cafe?,
        entryContext: JournalEntryContext = .cafe,
        locationName: String? = nil,
        drinkType: DrinkType,
        customDrinkType: String?,
        drinkSubtype: String?,
        brewMethod: String? = nil,
        equipment: String? = nil,
        homeCoffeeBagID: UUID? = nil,
        brewDetails: BrewDetails = .empty,
        caption: String,
        notes: String?,
        visibility: VisitVisibility,
        ratings: [String: Double],
        overallScore: Double? = nil,
        ratingTemplate: RatingTemplate,
        uploadState: VisitUploadState = .complete
    ) async throws -> RemoteVisitSummary {
        if entryContext == .cafe && cafe == nil {
            throw VisitServiceError.missingCafe
        }
        let remoteCafe: SupabaseCafeSummary?
        if entryContext == .cafe, let cafe {
            remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
        } else {
            remoteCafe = nil
        }
        let usesPrivateRecipePayload = entryContext == .recipe
            || brewDetails.recipeName?.remoteTrimmedNonEmpty != nil
        var visitBrewDetails = brewDetails
        var visitBrewMethod = brewMethod
        var visitEquipment = equipment
        if usesPrivateRecipePayload {
            // The socially readable visit row carries identity/display only.
            // Full instructions are consumed from the owner-bound stage by
            // the materialization trigger into recipe_versions.
            visitBrewDetails = .empty
            visitBrewDetails.recipeName = brewDetails.recipeName?.remoteTrimmedNonEmpty
                ?? drinkSubtype?.remoteTrimmedNonEmpty
            visitBrewDetails.recipeVersion = brewDetails.recipeVersion?.remoteTrimmedNonEmpty
            visitBrewMethod = nil
            visitEquipment = nil
        }
        let payload = try SupabaseVisitInsert.make(
            visitId: visitId,
            userId: userId,
            remoteCafe: remoteCafe,
            entryContext: entryContext,
            locationName: locationName,
            drinkType: drinkType,
            customDrinkType: customDrinkType,
            drinkSubtype: drinkSubtype,
            brewMethod: visitBrewMethod,
            equipment: visitEquipment,
            homeCoffeeBagID: homeCoffeeBagID,
            brewDetails: visitBrewDetails,
            recipePayloadContractVersion: usesPrivateRecipePayload ? 2 : nil,
            caption: caption,
            notes: notes,
            visibility: visibility,
            ratings: ratings,
            overallScore: overallScore,
            ratingTemplate: ratingTemplate,
            uploadState: uploadState
        )

        if usesPrivateRecipePayload {
            // Validate the safe social payload before creating an expiring
            // private stage. The visit insert then consumes that stage in its
            // materialization transaction.
            _ = try await client.rpc(
                "stage_visit_recipe_payload_v2",
                params: StageVisitRecipePayloadParameters(
                    visitID: visitId,
                    brewDetails: brewDetails,
                    brewMethod: brewMethod?.remoteTrimmedNonEmpty,
                    equipment: equipment?.remoteTrimmedNonEmpty
                )
            ).execute()
        }

        let row: SupabaseVisitRow
        do {
            row = try await withCompatibleVisitColumns { columns in
                try await client
                    .from("visits")
                    .insert(payload)
                    .select(columns)
                    .single()
                    .execute()
                    .value
            }
        } catch {
            // The insert may have committed immediately before a termination
            // or network failure. Reusing the client-generated visit id makes
            // retry idempotent without ever creating a second sip.
            if let existing = try? await fetchOwnedVisitSummary(
                visitId: visitId,
                userId: userId
            ) {
                try await updatePrivateNote(visitId: visitId, userId: userId, note: notes)
                return existing
            }
            throw error
        }

        try await updatePrivateNote(visitId: visitId, userId: userId, note: notes)

        return RemoteVisitSummary(visit: row, cafe: remoteCafe)
    }

    func attachPhotoURLs(
        visitId: UUID,
        photoURLs: [String],
        posterPhotoIndex: Int
    ) async throws -> RemoteVisitSummary {
        guard !photoURLs.isEmpty else {
            return try await fetchSavedVisitSummary(visitId: visitId)
        }

        // Retrying a failed submission must replace its partial attachment rather
        // than append duplicate photo rows.
        try await client
            .from("visit_photos")
            .delete()
            .eq("visit_id", value: visitId.uuidString)
            .execute()

        let photoRows = SupabaseVisitPhotoInsert.rows(
            visitId: visitId,
            photoURLs: photoURLs
        )

        try await client
            .from("visit_photos")
            .insert(photoRows)
            .execute()

        let update = SupabaseVisitPosterPhotoUpdate(
            posterPhotoURL: SupabaseVisitPhotoInsert.posterPhotoURL(
                photoURLs: photoURLs,
                posterPhotoIndex: posterPhotoIndex
            ) ?? photoURLs[0]
        )

        let row: SupabaseVisitRow = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .update(update)
                .eq("id", value: visitId.uuidString)
                .select(columns)
                .single()
                .execute()
                .value
        }

        let summaries = try await hydrate(rows: [row], includeAuthors: false)
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }

        return summary
    }

    func finalizeVisit(
        visitId: UUID,
        userId: UUID,
        visibility: VisitVisibility
    ) async throws -> RemoteVisitSummary {
        let update = SupabaseVisitPublicationUpdate(
            visibility: visibility.supabaseValue,
            uploadState: VisitUploadState.complete.rawValue
        )
        let row: SupabaseVisitRow = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .update(update)
                .eq("id", value: visitId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .select(columns)
                .single()
                .execute()
                .value
        }

        let summaries = try await hydrate(rows: [row], includeAuthors: false)
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }
        return summary
    }

    /// Commits the canonical visit row without hydrating photos, cafe data, or
    /// social state. The caller can durably record the irreversible boundary
    /// immediately after this request returns.
    func finalizeVisitPublication(
        visitId: UUID,
        userId: UUID,
        visibility: VisitVisibility
    ) async throws {
        let update = SupabaseVisitPublicationUpdate(
            visibility: visibility.supabaseValue,
            uploadState: VisitUploadState.complete.rawValue
        )
        let row: SupabaseOwnedVisitUploadStateRow = try await client
            .from("visits")
            .update(update)
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select("id, upload_state")
            .single()
            .execute()
            .value
        guard row.id == visitId,
              row.uploadState == VisitUploadState.complete.rawValue else {
            throw VisitServiceError.visitNotFound
        }
    }

    func markVisitUploadFailed(visitId: UUID, userId: UUID) async throws {
        let update = SupabaseVisitUploadStateUpdate(uploadState: VisitUploadState.failed.rawValue)
        try await client
            .from("visits")
            .update(update)
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    private func fetchSavedVisitSummary(visitId: UUID) async throws -> RemoteVisitSummary {
        let row: SupabaseVisitRow = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .select(columns)
                .eq("id", value: visitId.uuidString)
                .single()
                .execute()
                .value
        }

        let summaries = try await hydrate(rows: [row], includeAuthors: false)
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }

        return summary
    }

    func fetchOwnedVisitSummary(visitId: UUID, userId: UUID) async throws -> RemoteVisitSummary {
        let row: SupabaseVisitRow = try await withCompatibleVisitColumns { columns in
            try await client
                .from("visits")
                .select(columns)
                .eq("id", value: visitId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value
        }
        let summaries = try await hydrate(rows: [row], includeAuthors: false)
        guard let summary = summaries.first else { throw VisitServiceError.visitNotFound }
        return summary
    }

    private func withCompatibleVisitColumns<Value>(
        _ operation: (String) async throws -> Value
    ) async throws -> Value {
        try await withCafeSessionSchemaFallback { hasCafeSessions in
            try await operation(hasCafeSessions ? visitColumns : legacyVisitColumns)
        }
    }

    private func withCafeSessionSchemaFallback<Value>(
        _ operation: (Bool) async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation(true)
        } catch {
            guard VisitSchemaCompatibility.isMissingCafeSessionColumn(error) else {
                throw error
            }
            return try await operation(false)
        }
    }

    private func hydrate(
        rows: [SupabaseVisitRow],
        includeAuthors: Bool,
        currentUserId: UUID? = nil,
        includeSocialState: Bool = false
    ) async throws -> [RemoteVisitSummary] {
        guard !rows.isEmpty else { return [] }

        let cafeRows = rows.filter { $0.journalContext == .cafe }
        async let cafesRequest = cafeService.fetchCafes(ids: cafeRows.compactMap(\.cafeId))
        async let profilesRequest = includeAuthors
            ? profileService.fetchProfiles(ids: rows.map(\.userId))
            : []
        async let socialStatesRequest = includeSocialState
            ? fetchSocialStates(visitIds: rows.map(\.id), currentUserId: currentUserId)
            : [:]
        async let sessionSipCountsRequest = fetchVisibleSessionSipCounts(
            sessionIDs: cafeRows.compactMap(\.cafeSessionID)
        )
        async let cafePulseProjectionsRequest = fetchVisibleCafePulseProjections(
            sessionIDs: cafeRows.compactMap(\.cafeSessionID)
        )
        async let v3FeedProjectionsRequest = fetchVisibleV3FeedProjections(
            visitIDs: rows.map(\.id)
        )

        let (
            cafes,
            profiles,
            socialStates,
            sessionSipCounts,
            cafePulseProjections,
            v3FeedProjections
        ) = try await (
            cafesRequest,
            profilesRequest,
            socialStatesRequest,
            sessionSipCountsRequest,
            cafePulseProjectionsRequest,
            v3FeedProjectionsRequest
        )
        let cafeCache = Dictionary(uniqueKeysWithValues: cafes.map { ($0.id, $0) })
        let profileCache = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return rows.map { row in
            let cafeSessionID = row.journalContext == .cafe ? row.cafeSessionID : nil
            return RemoteVisitSummary(
                visit: row,
                cafe: row.journalContext == .cafe
                    ? row.cafeId.flatMap { cafeCache[$0] }
                    : nil,
                author: includeAuthors ? profileCache[row.userId] : nil,
                socialState: socialStates[row.id] ?? RemoteVisitSocialState(
                    likeCount: 0,
                    commentCount: 0,
                    currentUserHasLiked: false
                ),
                sessionSipCount: cafeSessionID.flatMap { sessionSipCounts[$0] } ?? 1,
                cafePulseProjection: cafeSessionID.flatMap { cafePulseProjections[$0] },
                v3FeedProjection: v3FeedProjections[row.id]
            )
        }
    }

    static func v3ProjectionBatches(visitIDs: [UUID]) -> [[UUID]] {
        var seen = Set<UUID>()
        let identifiers = visitIDs.filter { seen.insert($0).inserted }
        return stride(from: 0, to: identifiers.count, by: 100).map { start in
            Array(identifiers[start..<min(start + 100, identifiers.count)])
        }
    }

    private func fetchVisibleV3FeedProjections(
        visitIDs: some Collection<UUID>
    ) async -> [UUID: RemoteVisitV3FeedProjection] {
        let batches = Self.v3ProjectionBatches(visitIDs: Array(visitIDs))
        guard !batches.isEmpty else { return [:] }
        do {
            var projections: [UUID: RemoteVisitV3FeedProjection] = [:]
            for identifiers in batches {
                let rows: [RemoteVisitV3FeedProjection] = try await client
                    .rpc(
                        "get_visit_v3_feed_projections_v1",
                        params: V3FeedProjectionParameters(visitIDs: identifiers)
                    )
                    .execute()
                    .value
                for row in rows {
                    projections[row.visitID] = row
                }
            }
            return projections
        } catch {
            // Older backends keep the canonical sip score until the feed-safe
            // V3 projection migration is available.
            return [:]
        }
    }

    private func fetchVisibleSessionSipCounts(
        sessionIDs: some Collection<UUID>
    ) async throws -> [UUID: Int] {
        let identifiers = Array(Set(sessionIDs))
        guard !identifiers.isEmpty else { return [:] }
        let rows: [CafeSessionSipCountRow] = try await client
            .from("visits")
            .select("id, cafe_session_id")
            .in("cafe_session_id", values: identifiers.map(\.uuidString))
            .eq("upload_state", value: VisitUploadState.complete.rawValue)
            .execute()
            .value
        return Dictionary(grouping: rows.compactMap { row in
            row.cafeSessionID.map { ($0, row.id) }
        }, by: \.0)
        .mapValues(\.count)
    }

    private func fetchVisibleCafePulseProjections(
        sessionIDs: some Collection<UUID>
    ) async throws -> [UUID: RemoteCafePulseProjection] {
        let identifiers = Array(Set(sessionIDs))
        guard !identifiers.isEmpty else { return [:] }
        let rows: [RemoteCafePulseProjection] = try await client
            .from("cafe_experience_public_projections")
            .select(
                "session_id, includes_cafe_rating, includes_next_move, cafe_rating, next_move"
            )
            .in("session_id", values: identifiers.map(\.uuidString))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.sessionID, $0) })
    }

    private func fetchSocialStates(
        visitIds: some Collection<UUID>,
        currentUserId: UUID?
    ) async throws -> [UUID: RemoteVisitSocialState] {
        let identifiers = Array(Set(visitIds))
        guard !identifiers.isEmpty else { return [:] }
        let values = identifiers.map(\.uuidString)

        async let likesRequest = fetchLikeSummaries(visitIDs: values)
        async let commentsRequest: [VisitCommentSummaryRow] = client
            .from("comments")
            .select("visit_id")
            .in("visit_id", values: values)
            .execute()
            .value

        let (likes, comments) = try await (likesRequest, commentsRequest)
        let likesByVisit = Dictionary(grouping: likes, by: \.visitId)
        let commentCounts = Dictionary(grouping: comments, by: \.visitId)
            .mapValues(\.count)

        return Dictionary(uniqueKeysWithValues: identifiers.map { visitId in
            let visitLikes = likesByVisit[visitId] ?? []
            return (
                visitId,
                makeSocialState(
                    likes: visitLikes,
                    commentCount: commentCounts[visitId] ?? 0,
                    currentUserId: currentUserId
                )
            )
        })
    }

    private func fetchLikes(visitId: UUID) async throws -> [SupabaseVisitLikeRow] {
        do {
            return try await client
                .from("likes")
                .select(reactionLikeColumns)
                .eq("visit_id", value: visitId.uuidString)
                .execute()
                .value
        } catch where SupabaseBackendCompatibility.isMissingReactionKindColumn(error) {
            return try await client
                .from("likes")
                .select(likeColumns)
                .eq("visit_id", value: visitId.uuidString)
                .execute()
                .value
        }
    }

    private func fetchLikeSummaries(
        visitIDs: [String]
    ) async throws -> [VisitLikeSummaryRow] {
        do {
            return try await client
                .from("likes")
                .select("user_id, visit_id, reaction_kind")
                .in("visit_id", values: visitIDs)
                .execute()
                .value
        } catch where SupabaseBackendCompatibility.isMissingReactionKindColumn(error) {
            return try await client
                .from("likes")
                .select("user_id, visit_id")
                .in("visit_id", values: visitIDs)
                .execute()
                .value
        }
    }

    private func makeSocialState(
        likes: [SupabaseVisitLikeRow],
        commentCount: Int,
        currentUserId: UUID?
    ) -> RemoteVisitSocialState {
        let state = reactionState(from: likes, currentUserId: currentUserId)
        return RemoteVisitSocialState(
            likeCount: state.totalCount,
            commentCount: commentCount,
            currentUserHasLiked: state.viewerReaction != nil,
            reactionState: state
        )
    }

    private func makeSocialState(
        likes: [VisitLikeSummaryRow],
        commentCount: Int,
        currentUserId: UUID?
    ) -> RemoteVisitSocialState {
        let state = reactionState(from: likes, currentUserId: currentUserId)
        return RemoteVisitSocialState(
            likeCount: state.totalCount,
            commentCount: commentCount,
            currentUserHasLiked: state.viewerReaction != nil,
            reactionState: state
        )
    }

    private func reactionState(
        from likes: [SupabaseVisitLikeRow],
        currentUserId: UUID?
    ) -> VisitReactionState {
        buildReactionState(
            pairs: likes.map { ($0.userId, $0.reactionKind) },
            currentUserId: currentUserId
        )
    }

    private func reactionState(
        from likes: [VisitLikeSummaryRow],
        currentUserId: UUID?
    ) -> VisitReactionState {
        buildReactionState(
            pairs: likes.map { ($0.userId, $0.reactionKind) },
            currentUserId: currentUserId
        )
    }

    private func buildReactionState(
        pairs: [(UUID, PostReactionKind)],
        currentUserId: UUID?
    ) -> VisitReactionState {
        let grouped = Dictionary(grouping: pairs, by: { $0.1 })
        return VisitReactionState(
            viewerReaction: currentUserId.flatMap { userId in
                pairs.first(where: { $0.0 == userId })?.1
            },
            likeCount: grouped[.like]?.count ?? 0,
            loveCount: grouped[.love]?.count ?? 0,
            laughCount: grouped[.laugh]?.count ?? 0,
            yummyCount: grouped[.yummy]?.count ?? 0,
            totalCount: pairs.count
        )
    }

    private func hydrate(
        comments: [SupabaseVisitCommentRow]
    ) async throws -> [RemoteVisitComment] {
        let profiles = try await profileService.fetchProfiles(ids: comments.map(\.userId))
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        return comments.map { comment in
            RemoteVisitComment(comment: comment, author: profilesByID[comment.userId])
        }
    }

    private func fetchComments(visitId: UUID) async throws -> [RemoteVisitComment] {
        do {
            let rows: [SupabaseVisitCommentProjectionRow] = try await client.rpc(
                "list_visit_comments_v2",
                params: ["p_visit_id": visitId]
            ).execute().value
            return rows.map(\.remoteComment)
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            let comments: [SupabaseVisitCommentRow] = try await client
                .from("comments")
                .select(commentColumns)
                .eq("visit_id", value: visitId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            return try await hydrate(comments: comments)
        }
    }

}

private struct V3FeedProjectionParameters: Encodable {
    let visitIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case visitIDs = "p_visit_ids"
    }
}

struct CommentMentionSelection: Encodable, Equatable {
    let userID: UUID
    let token: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token
    }
}

private struct CreateCommentV2Parameters: Encodable {
    let pVisitId: UUID
    let pText: String
    let pParentCommentId: UUID?
    let pMentions: [CommentMentionSelection]

    enum CodingKeys: String, CodingKey {
        case pVisitId = "p_visit_id"
        case pText = "p_text"
        case pParentCommentId = "p_parent_comment_id"
        case pMentions = "p_mentions"
    }
}

private struct CreateCommentLegacyParameters: Encodable {
    let pVisitId: UUID
    let pText: String
    let pParentCommentId: UUID?
    let pMentionedUserIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case pVisitId = "p_visit_id"
        case pText = "p_text"
        case pParentCommentId = "p_parent_comment_id"
        case pMentionedUserIds = "p_mentioned_user_ids"
    }
}

private struct UpdateCommentParameters: Encodable {
    let pCommentID: UUID
    let pText: String

    enum CodingKeys: String, CodingKey {
        case pCommentID = "p_comment_id"
        case pText = "p_text"
    }
}

private struct RemoveCommentParameters: Encodable {
    let pCommentID: UUID
    let pReason: String

    enum CodingKeys: String, CodingKey {
        case pCommentID = "p_comment_id"
        case pReason = "p_reason"
    }
}

private struct DeleteOwnedVisitParameters: Encodable {
    let pVisitID: UUID

    enum CodingKeys: String, CodingKey {
        case pVisitID = "p_visit_id"
    }
}

private struct DeletedOwnedVisitPhotoRow: Decodable {
    let photoURL: String

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
    }
}

struct RemoteFeedCursor: Equatable {
    let createdAt: String
    let id: UUID
    let rankingScore: Double?

    init(_ summary: RemoteVisitSummary) {
        createdAt = summary.visit.createdAt
        id = summary.id
        rankingScore = summary.rankingScore
    }
}

private struct RankedFeedParameters: Encodable {
    let pScope: String
    let pLatitude: Double?
    let pLongitude: Double?
    let pLimit: Int
    let pAfterScore: Double?
    let pAfterCreatedAt: String?
    let pAfterID: UUID?

    enum CodingKeys: String, CodingKey {
        case pScope = "p_scope"
        case pLatitude = "p_latitude"
        case pLongitude = "p_longitude"
        case pLimit = "p_limit"
        case pAfterScore = "p_after_score"
        case pAfterCreatedAt = "p_after_created_at"
        case pAfterID = "p_after_id"
    }
}

private struct VisitLikeSummaryRow: Decodable {
    let userId: UUID
    let visitId: UUID
    let reactionKind: PostReactionKind

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case visitId = "visit_id"
        case reactionKind = "reaction_kind"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        visitId = try container.decode(UUID.self, forKey: .visitId)
        reactionKind = try container.decodeIfPresent(PostReactionKind.self, forKey: .reactionKind)
            ?? .like
    }
}

private struct SetVisitReactionParameters: Encodable {
    let pVisitID: UUID
    let pReactionKind: String?

    enum CodingKeys: String, CodingKey {
        case pVisitID = "p_visit_id"
        case pReactionKind = "p_reaction_kind"
    }
}

private struct VisitCommentSummaryRow: Decodable {
    let visitId: UUID

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
    }
}

private struct CafeSessionSipCountRow: Decodable {
    let id: UUID
    let cafeSessionID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case cafeSessionID = "cafe_session_id"
    }
}

private struct MapVisitRow: Decodable {
    let cafeId: UUID?
    let overallScore: Double
    let contextType: String?
    let cafeSessionID: UUID?
    let createdAt: String
    let posterPhotoURL: String?

    enum CodingKeys: String, CodingKey {
        case cafeId = "cafe_id"
        case overallScore = "overall_score"
        case contextType = "context_type"
        case cafeSessionID = "cafe_session_id"
        case createdAt = "created_at"
        case posterPhotoURL = "poster_photo_url"
    }
}

private enum MapVisitDateParser {
    static func date(from value: String) -> Date? {
        if let date = try? Date(
            value,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        ) {
            return date
        }
        return try? Date(value, strategy: Date.ISO8601FormatStyle())
    }
}

enum VisitSchemaCompatibility {
    static func isMissingCafeSessionColumn(_ error: Error) -> Bool {
        let description = "\(error.localizedDescription) \(String(describing: error))"
            .lowercased()
        let names = [
            "cafe_session_id",
            "cafe_session_order",
            "cafe_session_role"
        ]
        let missingSchemaMarkers = [
            "does not exist",
            "schema cache",
            "could not find",
            "pgrst204",
            "42703"
        ]
        return names.contains(where: description.contains)
            && missingSchemaMarkers.contains(where: description.contains)
    }
}

enum VisitServiceError: LocalizedError, Equatable {
    case visitNotFound
    case invalidUploadState(String)
    case missingCafe
    case missingRating
    case emptyCaption
    case emptyComment
    case expressiveReactionsUnavailable

    var errorDescription: String? {
        switch self {
        case .visitNotFound:
            return "Visit not found."
        case .invalidUploadState:
            return "Mugshot could not verify this visit's upload state."
        case .missingCafe:
            return "Choose a cafe before saving this journal entry."
        case .missingRating:
            return "Add at least one rating before saving your visit."
        case .emptyCaption:
            return "Add a caption before saving your visit."
        case .emptyComment:
            return "Write a comment before posting."
        case .expressiveReactionsUnavailable:
            return "Expressive reactions are not available yet. Try Like for now."
        }
    }
}

struct OwnerVisitBrewRow: Decodable {
    let id: UUID
    let brewMethod: String?
    let equipment: String?
    let brewDetails: BrewDetails?

    enum CodingKeys: String, CodingKey {
        case id, equipment
        case brewMethod = "brew_method"
        case brewDetails = "brew_details"
    }
}

private struct OwnerVisitBrewDetailsParameters: Encodable {
    let visitIDs: [UUID]?
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case visitIDs = "p_visit_ids"
        case limit = "p_limit"
    }
}

struct SupabaseVisitInsert: Encodable, Equatable {
    let id: UUID
    let userId: UUID
    let cafeId: UUID?
    let drinkType: String?
    let drinkTypeCustom: String?
    let drinkSubtype: String?
    let caption: String
    let visibility: String
    let uploadState: String
    let ratings: [String: Double]
    let overallScore: Double
    let contextType: String
    let locationName: String
    let cityState: String?
    let brewMethod: String?
    let equipment: String?
    let homeCoffeeBagID: UUID?
    let brewDetails: BrewDetails
    let recipePayloadContractVersion: Int?
    let categoryScores: [SupabaseVisitCategoryScore]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cafeId = "cafe_id"
        case drinkType = "drink_type"
        case drinkTypeCustom = "drink_type_custom"
        case drinkSubtype = "drink_subtype"
        case caption
        case visibility
        case uploadState = "upload_state"
        case ratings
        case overallScore = "overall_score"
        case contextType = "context_type"
        case locationName = "location_name"
        case cityState = "city_state"
        case brewMethod = "brew_method"
        case equipment
        case homeCoffeeBagID = "home_coffee_bag_id"
        case brewDetails = "brew_details"
        case recipePayloadContractVersion = "recipe_payload_contract_version"
        case categoryScores = "category_scores"
    }

    static func make(
        visitId: UUID = UUID(),
        userId: UUID,
        remoteCafe: SupabaseCafeSummary?,
        entryContext: JournalEntryContext = .cafe,
        locationName: String? = nil,
        drinkType: DrinkType,
        customDrinkType: String?,
        drinkSubtype: String?,
        brewMethod: String? = nil,
        equipment: String? = nil,
        homeCoffeeBagID: UUID? = nil,
        brewDetails: BrewDetails = .empty,
        recipePayloadContractVersion: Int? = nil,
        caption: String,
        notes _: String?,
        visibility: VisitVisibility,
        ratings: [String: Double],
        overallScore explicitOverallScore: Double? = nil,
        ratingTemplate: RatingTemplate,
        uploadState: VisitUploadState = .complete
    ) throws -> SupabaseVisitInsert {
        let normalizedCaption = try SipCaptionPolicy.validateAndNormalize(caption)
        let cleanRatings = clean(ratings: ratings, ratingTemplate: ratingTemplate)
        let overallScore: Double
        if let explicitOverallScore {
            guard explicitOverallScore >= 0.5,
                  explicitOverallScore <= 5,
                  explicitOverallScore.isFinite else {
                throw VisitServiceError.missingRating
            }
            overallScore = explicitOverallScore
        } else {
            // Backward compatibility for older pending records and callers.
            // The redesigned composer always supplies the authored quick score.
            overallScore = ratingTemplate.calculateOverallScore(ratings: cleanRatings)
        }

        guard overallScore > 0 else {
            throw VisitServiceError.missingRating
        }

        let persistedCafe = entryContext == .cafe ? remoteCafe : nil
        return SupabaseVisitInsert(
            id: visitId,
            userId: userId,
            cafeId: persistedCafe?.id,
            drinkType: drinkType == .other ? nil : drinkType.rawValue,
            drinkTypeCustom: drinkType == .other ? customDrinkType?.remoteTrimmedNonEmpty : nil,
            drinkSubtype: drinkSubtype?.remoteTrimmedNonEmpty,
            caption: normalizedCaption,
            visibility: visibility.supabaseValue,
            uploadState: uploadState.rawValue,
            ratings: cleanRatings,
            overallScore: overallScore,
            contextType: entryContext.rawValue,
            locationName: persistedCafe?.name
                ?? locationName?.remoteTrimmedNonEmpty
                ?? entryContext.locationFallback,
            cityState: persistedCafe?.city?.remoteTrimmedNonEmpty,
            brewMethod: brewMethod?.remoteTrimmedNonEmpty,
            equipment: equipment?.remoteTrimmedNonEmpty,
            homeCoffeeBagID: homeCoffeeBagID,
            brewDetails: brewDetails,
            recipePayloadContractVersion: recipePayloadContractVersion,
            categoryScores: categoryScores(
                ratings: cleanRatings,
                ratingTemplate: ratingTemplate
            )
        )
    }

    private static func clean(
        ratings: [String: Double],
        ratingTemplate: RatingTemplate
    ) -> [String: Double] {
        let categoryNames = Set(ratingTemplate.categories.map(\.name))
        return ratings.reduce(into: [:]) { result, pair in
            guard categoryNames.contains(pair.key),
                  pair.value > 0,
                  pair.value <= 5,
                  !pair.value.isNaN,
                  !pair.value.isInfinite else {
                return
            }
            result[pair.key] = pair.value
        }
    }

    private static func categoryScores(
        ratings: [String: Double],
        ratingTemplate: RatingTemplate
    ) -> [SupabaseVisitCategoryScore] {
        ratingTemplate.categories.compactMap { category in
            guard let score = ratings[category.name] else {
                return nil
            }

            return SupabaseVisitCategoryScore(
                name: category.name,
                score: score,
                weight: category.weight
            )
        }
    }
}

private struct SupabaseVisitPublicationUpdate: Encodable {
    let visibility: String
    let uploadState: String

    enum CodingKeys: String, CodingKey {
        case visibility
        case uploadState = "upload_state"
    }
}

private struct StageVisitRecipePayloadParameters: Encodable {
    let visitID: UUID
    let brewDetails: BrewDetails
    let brewMethod: String?
    let equipment: String?

    enum CodingKeys: String, CodingKey {
        case visitID = "p_visit_id"
        case brewDetails = "p_brew_details"
        case brewMethod = "p_brew_method"
        case equipment = "p_equipment"
    }
}

private struct SupabaseVisitUploadStateUpdate: Encodable {
    let uploadState: String

    enum CodingKeys: String, CodingKey {
        case uploadState = "upload_state"
    }
}

private struct SupabaseOwnedVisitUploadStateRow: Decodable {
    let id: UUID
    let uploadState: String

    enum CodingKeys: String, CodingKey {
        case id
        case uploadState = "upload_state"
    }
}

struct SupabaseVisitPhotoInsert: Encodable, Equatable {
    let visitId: UUID
    let photoURL: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case photoURL = "photo_url"
        case sortOrder = "sort_order"
    }

    static func rows(
        visitId: UUID,
        photoURLs: [String]
    ) -> [SupabaseVisitPhotoInsert] {
        photoURLs.enumerated().map { index, photoURL in
            SupabaseVisitPhotoInsert(
                visitId: visitId,
                photoURL: photoURL,
                sortOrder: index
            )
        }
    }

    static func posterPhotoURL(
        photoURLs: [String],
        posterPhotoIndex: Int
    ) -> String? {
        guard !photoURLs.isEmpty else {
            return nil
        }

        guard photoURLs.indices.contains(posterPhotoIndex) else {
            return photoURLs[0]
        }

        return photoURLs[posterPhotoIndex]
    }
}

private struct SupabaseVisitPosterPhotoUpdate: Encodable {
    let posterPhotoURL: String

    enum CodingKeys: String, CodingKey {
        case posterPhotoURL = "poster_photo_url"
    }
}

struct SupabaseVisitCategoryScore: Codable, Equatable, Identifiable {
    let name: String
    let score: Double
    let weight: Double

    var id: String { name }
}

extension VisitVisibility {
    var supabaseValue: String {
        switch self {
        case .private:
            return "private"
        case .friends:
            return "friends"
        case .everyone:
            return "everyone"
        }
    }
}
