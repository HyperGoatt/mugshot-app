//
//  VisitService.swift
//  testMugshot
//

import Foundation
import Supabase

final class VisitService {
    private let client: SupabaseClient
    private let cafeService: CafeService
    private let profileService: ProfileService

    private let visitColumns = """
    id, user_id, cafe_id, drink_type, drink_type_custom, drink_subtype, caption, notes, visibility, ratings, overall_score, poster_photo_url, context_type, location_name, city_state, brew_method, created_at
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

    func fetchRecentVisits(userId: UUID, limit: Int = 10) async throws -> [RemoteVisitSummary] {
        let rows: [SupabaseVisitRow] = try await client
            .from("visits")
            .select(visitColumns)
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return try await hydrate(rows: rows, includeAuthors: false)
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
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return try await hydrate(rows: rows, includeAuthors: false)
    }

    func fetchFeedVisits(scope: FeedScope, limit: Int = 25) async throws -> [RemoteVisitSummary] {
        var query = client
            .from("visits")
            .select(visitColumns)

        switch scope {
        case .friends:
            query = query.in("visibility", values: ["friends", "everyone"])
        case .everyone:
            query = query.eq("visibility", value: "everyone")
        }

        let rows: [SupabaseVisitRow] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return try await hydrate(rows: rows, includeAuthors: true)
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

        let summaries = try await hydrate(rows: [row], includeAuthors: true)
        guard let summary = summaries.first else {
            throw VisitServiceError.visitNotFound
        }

        let photos: [SupabaseVisitPhotoRow] = try await client
            .from("visit_photos")
            .select(photoColumns)
            .eq("visit_id", value: visitId.uuidString)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value

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
            .order("created_at", ascending: true)
            .execute()
            .value

        return RemoteVisitDetail(
            summary: summary,
            photos: photos,
            comments: try await hydrate(comments: comments),
            likeCount: likes.count,
            currentUserHasLiked: currentUserId.map { userId in
                likes.contains { $0.userId == userId }
            } ?? false
        )
    }

    func createNoPhotoVisit(
        userId: UUID,
        cafe: Cafe,
        drinkType: DrinkType,
        customDrinkType: String?,
        drinkSubtype: String?,
        caption: String,
        notes: String?,
        visibility: VisitVisibility,
        ratings: [String: Double],
        ratingTemplate: RatingTemplate
    ) async throws -> RemoteVisitSummary {
        let remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
        let payload = try SupabaseVisitInsert.make(
            userId: userId,
            remoteCafe: remoteCafe,
            drinkType: drinkType,
            customDrinkType: customDrinkType,
            drinkSubtype: drinkSubtype,
            caption: caption,
            notes: notes,
            visibility: visibility,
            ratings: ratings,
            ratingTemplate: ratingTemplate
        )

        let row: SupabaseVisitRow = try await client
            .from("visits")
            .insert(payload)
            .select(visitColumns)
            .single()
            .execute()
            .value

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

    private func hydrate(
        rows: [SupabaseVisitRow],
        includeAuthors: Bool
    ) async throws -> [RemoteVisitSummary] {
        var cafeCache: [UUID: SupabaseCafeSummary] = [:]
        var profileCache: [UUID: SupabaseUserProfile] = [:]
        var summaries: [RemoteVisitSummary] = []

        for row in rows {
            var cafe: SupabaseCafeSummary?
            if let cafeId = row.cafeId {
                if let cachedCafe = cafeCache[cafeId] {
                    cafe = cachedCafe
                } else if let fetchedCafe = try await cafeService.fetchCafe(id: cafeId) {
                    cafeCache[cafeId] = fetchedCafe
                    cafe = fetchedCafe
                }
            }

            var author: SupabaseUserProfile?
            if includeAuthors {
                if let cachedProfile = profileCache[row.userId] {
                    author = cachedProfile
                } else if let fetchedProfile = try await profileService.fetchProfile(userId: row.userId) {
                    profileCache[row.userId] = fetchedProfile
                    author = fetchedProfile
                }
            }

            summaries.append(RemoteVisitSummary(visit: row, cafe: cafe, author: author))
        }

        return summaries
    }

    private func hydrate(
        comments: [SupabaseVisitCommentRow]
    ) async throws -> [RemoteVisitComment] {
        var profileCache: [UUID: SupabaseUserProfile] = [:]
        var remoteComments: [RemoteVisitComment] = []

        for comment in comments {
            let author: SupabaseUserProfile?
            if let cachedProfile = profileCache[comment.userId] {
                author = cachedProfile
            } else if let fetchedProfile = try await profileService.fetchProfile(userId: comment.userId) {
                profileCache[comment.userId] = fetchedProfile
                author = fetchedProfile
            } else {
                author = nil
            }

            remoteComments.append(RemoteVisitComment(comment: comment, author: author))
        }

        return remoteComments
    }

}

enum VisitServiceError: LocalizedError, Equatable {
    case visitNotFound
    case missingRating

    var errorDescription: String? {
        switch self {
        case .visitNotFound:
            return "Visit not found."
        case .missingRating:
            return "Add at least one rating before saving your visit."
        }
    }
}

struct SupabaseVisitInsert: Encodable, Equatable {
    let userId: UUID
    let cafeId: UUID
    let drinkType: String?
    let drinkTypeCustom: String?
    let drinkSubtype: String?
    let caption: String
    let notes: String?
    let visibility: String
    let ratings: [String: Double]
    let overallScore: Double
    let contextType: String
    let locationName: String
    let cityState: String?
    let categoryScores: [SupabaseVisitCategoryScore]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case cafeId = "cafe_id"
        case drinkType = "drink_type"
        case drinkTypeCustom = "drink_type_custom"
        case drinkSubtype = "drink_subtype"
        case caption
        case notes
        case visibility
        case ratings
        case overallScore = "overall_score"
        case contextType = "context_type"
        case locationName = "location_name"
        case cityState = "city_state"
        case categoryScores = "category_scores"
    }

    static func make(
        userId: UUID,
        remoteCafe: SupabaseCafeSummary,
        drinkType: DrinkType,
        customDrinkType: String?,
        drinkSubtype: String?,
        caption: String,
        notes: String?,
        visibility: VisitVisibility,
        ratings: [String: Double],
        ratingTemplate: RatingTemplate
    ) throws -> SupabaseVisitInsert {
        let cleanRatings = clean(ratings: ratings, ratingTemplate: ratingTemplate)
        let overallScore = ratingTemplate.calculateOverallScore(ratings: cleanRatings)

        guard overallScore > 0 else {
            throw VisitServiceError.missingRating
        }

        return SupabaseVisitInsert(
            userId: userId,
            cafeId: remoteCafe.id,
            drinkType: drinkType == .other ? nil : drinkType.rawValue,
            drinkTypeCustom: drinkType == .other ? customDrinkType?.remoteTrimmedNonEmpty : nil,
            drinkSubtype: drinkSubtype?.remoteTrimmedNonEmpty,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes?.remoteTrimmedNonEmpty,
            visibility: visibility.supabaseValue,
            ratings: cleanRatings,
            overallScore: overallScore,
            contextType: "Cafe",
            locationName: remoteCafe.name,
            cityState: remoteCafe.city?.remoteTrimmedNonEmpty,
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

struct SupabaseVisitCategoryScore: Encodable, Equatable {
    let name: String
    let score: Double
    let weight: Double
}

private extension VisitVisibility {
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
