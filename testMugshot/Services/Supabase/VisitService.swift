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
    id, user_id, cafe_id, drink_type, drink_type_custom, drink_subtype, caption, visibility, upload_state, ratings, category_scores, overall_score, poster_photo_url, context_type, location_name, city_state, brew_method, equipment, brew_details, recipe_version_id, created_at
    """

    private let photoColumns = """
    id, visit_id, photo_url, sort_order, created_at
    """

    private let likeColumns = """
    id, user_id, visit_id, created_at
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
        let rows: [SupabaseVisitRow] = try await client
            .from("visits")
            .select(visitColumns)
            .eq("user_id", value: userId.uuidString)
            .eq("upload_state", value: VisitUploadState.complete.rawValue)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return try await hydrate(
            rows: rows,
            includeAuthors: false,
            currentUserId: userId,
            includeSocialState: includeSocialState
        )
    }

    func fetchOwnerSipCount(userId: UUID) async throws -> Int {
        let response = try await client
            .from("visits")
            .select(head: true, count: .exact)
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
        let rows: [SupabaseVisitRow] = try await client
            .from("visits")
            .select(visitColumns)
            .eq("cafe_id", value: cafeId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .eq("upload_state", value: VisitUploadState.complete.rawValue)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return try await hydrate(rows: rows, includeAuthors: false)
    }

    func fetchVisibleCafeVisits(
        cafeId: UUID,
        currentUserId: UUID?,
        limit: Int = 20
    ) async throws -> [RemoteVisitSummary] {
        let rows: [SupabaseVisitRow] = try await client
            .from("visits")
            .select(visitColumns)
            .eq("cafe_id", value: cafeId.uuidString)
            .eq("upload_state", value: VisitUploadState.complete.rawValue)
            .order("created_at", ascending: false)
            .order("id", ascending: false)
            .limit(limit)
            .execute()
            .value

        return try await hydrate(
            rows: rows,
            includeAuthors: true,
            currentUserId: currentUserId,
            includeSocialState: true
        )
    }

    func fetchMapVisitSeeds(userId: UUID) async throws -> [RemoteMapVisitSeed] {
        let rows: [MapVisitRow] = try await client
            .from("visits")
            .select("cafe_id, overall_score")
            .eq("user_id", value: userId.uuidString)
            .eq("upload_state", value: VisitUploadState.complete.rawValue)
            .not("cafe_id", operator: .is, value: "null")
            .execute()
            .value
        let cafes = try await cafeService.fetchCafes(ids: rows.compactMap(\.cafeId))
        let cafesByID = Dictionary(uniqueKeysWithValues: cafes.map { ($0.id, $0) })
        return rows.compactMap { row in
            guard let cafeId = row.cafeId, let cafe = cafesByID[cafeId] else { return nil }
            return RemoteMapVisitSeed(cafe: cafe, overallScore: row.overallScore)
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

        let rows: [SupabaseVisitRow] = try await client
            .from("visits")
            .select(visitColumns)
            .in("id", values: references.map { $0.visitID.uuidString })
            .execute()
            .value
        let summaries = try await hydrate(
            rows: rows,
            includeAuthors: true,
            currentUserId: currentUserId,
            includeSocialState: true
        )
        let summariesByID = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        return references.compactMap { reference in
            guard let summary = summariesByID[reference.visitID] else { return nil }
            return RemoteVisitSummary(
                visit: summary.visit,
                cafe: summary.cafe,
                author: summary.author,
                socialState: summary.socialState,
                rankingScore: reference.feedScore,
                recommendationReason: reference.rankingReason,
                recommendationReasonType: reference.reasonType
            )
        }
    }

    func fetchVisitDetail(
        visitId: UUID,
        currentUserId: UUID?
    ) async throws -> RemoteVisitDetail {
        let rows: [SupabaseVisitRow] = try await client
            .from("visits")
            .select(visitColumns)
            .eq("id", value: visitId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            throw VisitServiceError.visitNotFound
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
        async let likesRequest: [SupabaseVisitLikeRow] = client
            .from("likes")
            .select(likeColumns)
            .eq("visit_id", value: visitId.uuidString)
            .execute()
            .value
        async let commentsRequest: [SupabaseVisitCommentRow] = client
            .from("comments")
            .select(commentColumns)
            .eq("visit_id", value: visitId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        let (summaries, photos, likes, comments) = try await (
            summariesRequest,
            photosRequest,
            likesRequest,
            commentsRequest
        )
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }

        let privateNote: String?
        if currentUserId == row.userId {
            privateNote = try await fetchPrivateNote(visitId: visitId, userId: row.userId)
        } else {
            privateNote = nil
        }

        return RemoteVisitDetail(
            summary: summary,
            photos: photos,
            comments: try await hydrate(comments: comments),
            likeCount: likes.count,
            currentUserHasLiked: currentUserId.map { userId in
                likes.contains { $0.userId == userId }
            } ?? false,
            privateNote: privateNote
        )
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
        let likes: [SupabaseVisitLikeRow] = try await client
            .from("likes")
            .select(likeColumns)
            .eq("visit_id", value: visitId.uuidString)
            .execute()
            .value

        let comments: [SupabaseVisitCommentRow] = try await client
            .from("comments")
            .select(commentColumns)
            .eq("visit_id", value: visitId.uuidString)
            .execute()
            .value

        return RemoteVisitSocialState(
            likeCount: likes.count,
            commentCount: comments.count,
            currentUserHasLiked: currentUserId.map { userId in
                likes.contains { $0.userId == userId }
            } ?? false
        )
    }

    func toggleLike(
        visitId: UUID,
        userId: UUID,
        currentlyLiked: Bool
    ) async throws -> RemoteVisitSocialState {
        if currentlyLiked {
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
        mentionedUserIds: [UUID] = []
    ) async throws -> RemoteVisitSocialState {
        guard let trimmedText = text.remoteTrimmedNonEmpty else {
            throw VisitServiceError.emptyComment
        }

        try await client
            .rpc(
                "create_comment",
                params: CreateCommentParameters(
                    pVisitId: visitId,
                    pText: trimmedText,
                    pParentCommentId: parentCommentId,
                    pMentionedUserIds: mentionedUserIds
                )
            )
            .execute()

        return try await fetchSocialState(
            visitId: visitId,
            currentUserId: userId
        )
    }

    func updateVisit(
        visitId: UUID,
        userId: UUID,
        update: SupabaseVisitUpdate
    ) async throws -> RemoteVisitSummary {
        let row: SupabaseVisitRow = try await client
            .from("visits")
            .update(update)
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select(visitColumns)
            .single()
            .execute()
            .value

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
        if let cafe {
            remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
        } else {
            remoteCafe = nil
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
            brewMethod: brewMethod,
            equipment: equipment,
            brewDetails: brewDetails,
            caption: caption,
            notes: notes,
            visibility: visibility,
            ratings: ratings,
            overallScore: overallScore,
            ratingTemplate: ratingTemplate,
            uploadState: uploadState
        )

        let row: SupabaseVisitRow
        do {
            row = try await client
                .from("visits")
                .insert(payload)
                .select(visitColumns)
                .single()
                .execute()
                .value
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

        let row: SupabaseVisitRow = try await client
            .from("visits")
            .update(update)
            .eq("id", value: visitId.uuidString)
            .select(visitColumns)
            .single()
            .execute()
            .value

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
        let row: SupabaseVisitRow = try await client
            .from("visits")
            .update(update)
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select(visitColumns)
            .single()
            .execute()
            .value

        let summaries = try await hydrate(rows: [row], includeAuthors: false)
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }
        return summary
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
        let row: SupabaseVisitRow = try await client
            .from("visits")
            .select(visitColumns)
            .eq("id", value: visitId.uuidString)
            .single()
            .execute()
            .value

        let summaries = try await hydrate(rows: [row], includeAuthors: false)
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }

        return summary
    }

    private func fetchOwnedVisitSummary(visitId: UUID, userId: UUID) async throws -> RemoteVisitSummary {
        let row: SupabaseVisitRow = try await client
            .from("visits")
            .select(visitColumns)
            .eq("id", value: visitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value
        let summaries = try await hydrate(rows: [row], includeAuthors: false)
        guard let summary = summaries.first else { throw VisitServiceError.visitNotFound }
        return summary
    }

    private func hydrate(
        rows: [SupabaseVisitRow],
        includeAuthors: Bool,
        currentUserId: UUID? = nil,
        includeSocialState: Bool = false
    ) async throws -> [RemoteVisitSummary] {
        guard !rows.isEmpty else { return [] }

        async let cafesRequest = cafeService.fetchCafes(ids: rows.compactMap(\.cafeId))
        async let profilesRequest = includeAuthors
            ? profileService.fetchProfiles(ids: rows.map(\.userId))
            : []
        async let socialStatesRequest = includeSocialState
            ? fetchSocialStates(visitIds: rows.map(\.id), currentUserId: currentUserId)
            : [:]

        let (cafes, profiles, socialStates) = try await (
            cafesRequest,
            profilesRequest,
            socialStatesRequest
        )
        let cafeCache = Dictionary(uniqueKeysWithValues: cafes.map { ($0.id, $0) })
        let profileCache = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return rows.map { row in
            RemoteVisitSummary(
                visit: row,
                cafe: row.cafeId.flatMap { cafeCache[$0] },
                author: includeAuthors ? profileCache[row.userId] : nil,
                socialState: socialStates[row.id] ?? RemoteVisitSocialState(
                    likeCount: 0,
                    commentCount: 0,
                    currentUserHasLiked: false
                )
            )
        }
    }

    private func fetchSocialStates(
        visitIds: some Collection<UUID>,
        currentUserId: UUID?
    ) async throws -> [UUID: RemoteVisitSocialState] {
        let identifiers = Array(Set(visitIds))
        guard !identifiers.isEmpty else { return [:] }
        let values = identifiers.map(\.uuidString)

        async let likesRequest: [VisitLikeSummaryRow] = client
            .from("likes")
            .select("user_id, visit_id")
            .in("visit_id", values: values)
            .execute()
            .value
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
                RemoteVisitSocialState(
                    likeCount: visitLikes.count,
                    commentCount: commentCounts[visitId] ?? 0,
                    currentUserHasLiked: currentUserId.map { userId in
                        visitLikes.contains { $0.userId == userId }
                    } ?? false
                )
            )
        })
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

}

private struct CreateCommentParameters: Encodable {
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

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case visitId = "visit_id"
    }
}

private struct VisitCommentSummaryRow: Decodable {
    let visitId: UUID

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
    }
}

private struct MapVisitRow: Decodable {
    let cafeId: UUID?
    let overallScore: Double

    enum CodingKeys: String, CodingKey {
        case cafeId = "cafe_id"
        case overallScore = "overall_score"
    }
}

enum VisitServiceError: LocalizedError, Equatable {
    case visitNotFound
    case missingCafe
    case missingRating
    case emptyCaption
    case emptyComment

    var errorDescription: String? {
        switch self {
        case .visitNotFound:
            return "Visit not found."
        case .missingCafe:
            return "Choose a cafe before saving this journal entry."
        case .missingRating:
            return "Add at least one rating before saving your visit."
        case .emptyCaption:
            return "Add a caption before saving your visit."
        case .emptyComment:
            return "Write a comment before posting."
        }
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
    let brewDetails: BrewDetails
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
        case brewDetails = "brew_details"
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
        brewDetails: BrewDetails = .empty,
        caption: String,
        notes _: String?,
        visibility: VisitVisibility,
        ratings: [String: Double],
        overallScore explicitOverallScore: Double? = nil,
        ratingTemplate: RatingTemplate,
        uploadState: VisitUploadState = .complete
    ) throws -> SupabaseVisitInsert {
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

        return SupabaseVisitInsert(
            id: visitId,
            userId: userId,
            cafeId: remoteCafe?.id,
            drinkType: drinkType == .other ? nil : drinkType.rawValue,
            drinkTypeCustom: drinkType == .other ? customDrinkType?.remoteTrimmedNonEmpty : nil,
            drinkSubtype: drinkSubtype?.remoteTrimmedNonEmpty,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            visibility: visibility.supabaseValue,
            uploadState: uploadState.rawValue,
            ratings: cleanRatings,
            overallScore: overallScore,
            contextType: entryContext.rawValue,
            locationName: remoteCafe?.name ?? locationName?.remoteTrimmedNonEmpty ?? entryContext.locationFallback,
            cityState: remoteCafe?.city?.remoteTrimmedNonEmpty,
            brewMethod: brewMethod?.remoteTrimmedNonEmpty,
            equipment: equipment?.remoteTrimmedNonEmpty,
            brewDetails: brewDetails,
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

private struct SupabaseVisitUploadStateUpdate: Encodable {
    let uploadState: String

    enum CodingKeys: String, CodingKey {
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
