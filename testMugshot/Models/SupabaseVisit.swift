//
//  SupabaseVisit.swift
//  testMugshot
//

import Foundation

enum VisitUploadState: String, Codable, CaseIterable {
    case uploading
    case complete
    case failed
}

struct SupabaseVisitRow: Identifiable, Decodable, Equatable {
    let id: UUID
    let userId: UUID
    let cafeId: UUID?
    let drinkType: String?
    let drinkTypeCustom: String?
    let drinkSubtype: String?
    let caption: String
    // Kept for local/test compatibility. Remote visit queries deliberately do
    // not decode private notes from the social visit row.
    var notes: String? = nil
    let visibility: String
    let uploadState: String
    let ratings: [String: Double]
    let categoryScores: [SupabaseVisitCategoryScore]?
    let overallScore: Double
    let posterPhotoURL: String?
    let contextType: String?
    let locationName: String?
    let cityState: String?
    let brewMethod: String?
    let equipment: String?
    let brewDetails: BrewDetails?
    let recipeVersionID: UUID?
    let cafeSessionID: UUID?
    let cafeSessionOrder: Int?
    let cafeSessionRole: String?
    let createdAt: String

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
        case categoryScores = "category_scores"
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
        case contextType = "context_type"
        case locationName = "location_name"
        case cityState = "city_state"
        case brewMethod = "brew_method"
        case equipment
        case brewDetails = "brew_details"
        case recipeVersionID = "recipe_version_id"
        case cafeSessionID = "cafe_session_id"
        case cafeSessionOrder = "cafe_session_order"
        case cafeSessionRole = "cafe_session_role"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        userId: UUID,
        cafeId: UUID?,
        drinkType: String?,
        drinkTypeCustom: String?,
        drinkSubtype: String?,
        caption: String,
        notes: String?,
        visibility: String,
        uploadState: String = VisitUploadState.complete.rawValue,
        ratings: [String: Double],
        categoryScores: [SupabaseVisitCategoryScore]? = nil,
        overallScore: Double,
        posterPhotoURL: String?,
        contextType: String?,
        locationName: String?,
        cityState: String?,
        brewMethod: String?,
        createdAt: String,
        equipment: String? = nil,
        brewDetails: BrewDetails? = nil,
        recipeVersionID: UUID? = nil,
        cafeSessionID: UUID? = nil,
        cafeSessionOrder: Int? = nil,
        cafeSessionRole: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.cafeId = cafeId
        self.drinkType = drinkType
        self.drinkTypeCustom = drinkTypeCustom
        self.drinkSubtype = drinkSubtype
        self.caption = caption
        self.notes = notes
        self.visibility = visibility
        self.uploadState = uploadState
        self.ratings = ratings
        self.categoryScores = categoryScores
        self.overallScore = overallScore
        self.posterPhotoURL = posterPhotoURL
        self.contextType = contextType
        self.locationName = locationName
        self.cityState = cityState
        self.brewMethod = brewMethod
        self.equipment = equipment
        self.brewDetails = brewDetails
        self.recipeVersionID = recipeVersionID
        self.cafeSessionID = cafeSessionID
        self.cafeSessionOrder = cafeSessionOrder
        self.cafeSessionRole = cafeSessionRole
        self.createdAt = createdAt
    }

    var createdAtDate: Date {
        createdAt.remoteISO8601Date ?? Date.distantPast
    }

    var backendVisibilityLabel: String {
        switch visibility.lowercased() {
        case "private":
            return "Private"
        case "friends":
            return "Friends"
        case "everyone":
            return "Public"
        default:
            return visibility.capitalized
        }
    }

    var drinkDisplayName: String {
        if let subtype = drinkSubtype?.remoteTrimmedNonEmpty {
            return subtype
        }
        if let custom = drinkTypeCustom?.remoteTrimmedNonEmpty {
            return custom
        }
        return drinkType?.remoteTrimmedNonEmpty ?? "Drink"
    }

    var drinkCategoryDisplayName: String? {
        if let custom = drinkTypeCustom?.remoteTrimmedNonEmpty {
            return custom
        }
        return drinkType?.remoteTrimmedNonEmpty
    }

    var contextDisplayName: String {
        guard let context = contextType?.remoteTrimmedNonEmpty else {
            return "Cafe"
        }
        return context == "Cafe" ? "Cafe" : context.capitalized
    }

    var journalContext: JournalEntryContext {
        if JournalEntryContext(backendValue: contextType) == .home,
           recipeVersionID != nil {
            return .recipe
        }
        return JournalEntryContext(backendValue: contextType)
    }

    var isCafeSessionPrimary: Bool {
        cafeSessionID == nil || cafeSessionRole == CafeSessionSipRole.primary.rawValue
    }

    var structuredBrewDetails: BrewDetails {
        brewDetails ?? .empty
    }

    var trimmedNotes: String? {
        notes?.remoteTrimmedNonEmpty
    }

    var orderedRatingScores: [SupabaseVisitCategoryScore] {
        if let categoryScores, !categoryScores.isEmpty {
            return categoryScores
        }
        return ratings.keys.sorted().compactMap { name in
            guard let score = ratings[name] else { return nil }
            return SupabaseVisitCategoryScore(name: name, score: score, weight: 1)
        }
    }
}

struct SupabaseVisitPhotoRow: Identifiable, Decodable, Equatable {
    let id: UUID
    let visitId: UUID
    let photoURL: String
    let sortOrder: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case visitId = "visit_id"
        case photoURL = "photo_url"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct SupabaseVisitLikeRow: Identifiable, Decodable, Equatable {
    let id: UUID
    let userId: UUID
    let visitId: UUID
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case visitId = "visit_id"
        case createdAt = "created_at"
    }
}

struct SupabaseVisitLikeInsert: Encodable, Equatable {
    let userId: UUID
    let visitId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case visitId = "visit_id"
    }
}

struct SupabaseVisitCommentRow: Identifiable, Decodable, Equatable {
    let id: UUID
    let userId: UUID
    let visitId: UUID
    let text: String
    let createdAt: String
    let parentCommentId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case visitId = "visit_id"
        case text
        case createdAt = "created_at"
        case parentCommentId = "parent_comment_id"
    }

    var createdAtDate: Date {
        createdAt.remoteISO8601Date ?? Date.distantPast
    }
}

struct SupabaseVisitCommentInsert: Encodable, Equatable {
    let userId: UUID
    let visitId: UUID
    let text: String
    let parentCommentId: UUID?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case visitId = "visit_id"
        case text
        case parentCommentId = "parent_comment_id"
    }

    static func make(
        userId: UUID,
        visitId: UUID,
        text: String,
        parentCommentId: UUID? = nil
    ) throws -> SupabaseVisitCommentInsert {
        guard let trimmedText = text.remoteTrimmedNonEmpty else {
            throw VisitServiceError.emptyComment
        }

        return SupabaseVisitCommentInsert(
            userId: userId,
            visitId: visitId,
            text: trimmedText,
            parentCommentId: parentCommentId
        )
    }
}

struct SupabaseVisitUpdate: Encodable, Equatable {
    let caption: String
    let visibility: String

    static func make(
        caption: String,
        visibility: VisitVisibility
    ) throws -> SupabaseVisitUpdate {
        return SupabaseVisitUpdate(
            caption: try SipCaptionPolicy.validateAndNormalize(caption),
            visibility: visibility.supabaseValue
        )
    }
}

struct SupabaseVisitPrivateNoteRow: Decodable, Equatable {
    let visitId: UUID
    let userId: UUID
    let note: String

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case userId = "user_id"
        case note
    }
}

struct SupabaseVisitPrivateNoteUpsert: Encodable, Equatable {
    let visitId: UUID
    let userId: UUID
    let note: String

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case userId = "user_id"
        case note
    }
}

struct RemoteVisitComment: Identifiable, Equatable {
    let comment: SupabaseVisitCommentRow
    let author: SupabaseUserProfile?

    var id: UUID { comment.id }

    var authorDisplayName: String {
        author?.displayName.remoteTrimmedNonEmpty ?? author?.username ?? "Mugshot User"
    }

    var authorUsername: String {
        author?.username ?? "user"
    }

    var authorInitial: String {
        String(authorUsername.prefix(1)).uppercased()
    }
}

struct RemoteVisitSocialState: Equatable {
    let likeCount: Int
    let commentCount: Int
    let currentUserHasLiked: Bool
}

struct RemoteCafePulseProjection: Decodable, Equatable {
    let sessionID: UUID
    let includesCafeRating: Bool
    let includesNextMove: Bool
    let cafeRating: Double?
    let nextMoveValue: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case includesCafeRating = "includes_cafe_rating"
        case includesNextMove = "includes_next_move"
        case cafeRating = "cafe_rating"
        case nextMoveValue = "next_move"
    }

    var nextMove: CafeNextMoveKind? {
        nextMoveValue.flatMap(CafeNextMoveKind.init(rawValue:))
    }
}

/// Caller-bound, allowlisted recipe payload returned only by
/// `get_recipe_projection_for_visit_v1`. Social visit rows never populate this
/// type from raw `visits.brew_details`.
struct RemoteVisitRecipeProjection: Decodable, Equatable {
    let recipeIdentityID: UUID
    let recipeVersionID: UUID
    let recipeName: String
    let versionNumber: Int
    let versionLabel: String?
    let visibilityValue: String
    let sourceKindValue: String
    let sourceRecipeVersionID: UUID?
    let owner: RemoteRecipeOwnerProjection?
    let brewMethod: String?
    let equipment: String?
    let brewDetails: BrewDetails
    let canSaveAndAdapt: Bool

    enum CodingKeys: String, CodingKey {
        case recipeIdentityID = "recipe_identity_id"
        case recipeVersionID = "recipe_version_id"
        case recipeName = "recipe_name"
        case versionNumber = "version_number"
        case versionLabel = "version_label"
        case visibilityValue = "visibility"
        case sourceKindValue = "source_kind"
        case sourceRecipeVersionID = "source_recipe_version_id"
        case owner
        case brewMethod = "brew_method"
        case equipment
        case brewDetails = "brew_details"
        case canSaveAndAdapt = "can_save_and_adapt"
    }

    init(
        recipeIdentityID: UUID,
        recipeVersionID: UUID,
        recipeName: String,
        versionNumber: Int,
        versionLabel: String?,
        visibilityValue: String,
        sourceKindValue: String,
        sourceRecipeVersionID: UUID?,
        owner: RemoteRecipeOwnerProjection? = nil,
        brewMethod: String?,
        equipment: String?,
        brewDetails: BrewDetails,
        canSaveAndAdapt: Bool
    ) {
        self.recipeIdentityID = recipeIdentityID
        self.recipeVersionID = recipeVersionID
        self.recipeName = recipeName
        self.versionNumber = versionNumber
        self.versionLabel = versionLabel
        self.visibilityValue = visibilityValue
        self.sourceKindValue = sourceKindValue
        self.sourceRecipeVersionID = sourceRecipeVersionID
        self.owner = owner
        self.brewMethod = brewMethod
        self.equipment = equipment
        self.brewDetails = brewDetails
        self.canSaveAndAdapt = canSaveAndAdapt
    }

    var resolvedBrewDetails: BrewDetails {
        var details = brewDetails
        details.recipeIdentityID = recipeIdentityID
        details.recipeName = recipeName
        details.recipeVersion = versionLabel?.remoteTrimmedNonEmpty
            ?? "Version \(versionNumber)"
        return details
    }
}

struct RemoteRecipeOwnerProjection: Decodable, Equatable {
    let id: UUID
    let displayName: String?
    let username: String
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
    }

    var personLabel: String {
        displayName?.remoteTrimmedNonEmpty ?? "@\(username)"
    }
}

struct RemoteVisitRecipeIdentityProjection: Decodable, Equatable {
    let recipeIdentityID: UUID
    let recipeVersionID: UUID
    let recipeName: String
    let versionNumber: Int
    let versionLabel: String?
    let ownerID: UUID
    let ownerDisplayName: String?
    let ownerUsername: String
    let ownerAvatarURL: String?

    enum CodingKeys: String, CodingKey {
        case recipeIdentityID = "recipe_identity_id"
        case recipeVersionID = "recipe_version_id"
        case recipeName = "recipe_name"
        case versionNumber = "version_number"
        case versionLabel = "version_label"
        case ownerID = "owner_id"
        case ownerDisplayName = "owner_display_name"
        case ownerUsername = "owner_username"
        case ownerAvatarURL = "owner_avatar_url"
    }

    var ownerLabel: String {
        ownerDisplayName?.remoteTrimmedNonEmpty ?? "@\(ownerUsername)"
    }
}

/// Viewer-safe identity projection for ordinary post tags. The backing RPC
/// already applies post visibility, profile visibility, blocking, and active
/// enforcement before a row reaches the client.
struct RemoteVisitTag: Decodable, Identifiable, Equatable {
    let userID: UUID
    let displayName: String?
    let username: String
    let avatarURL: String?
    let taggedAt: String

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case taggedAt = "tagged_at"
    }

    var personLabel: String {
        displayName?.remoteTrimmedNonEmpty ?? "@\(username)"
    }
}

/// Caller-bound shared presentation. The server returns nil when fewer than
/// two independently visible contributions remain. The client repeats that
/// minimum defensively so malformed or stale payloads never imply hidden
/// participants.
struct RemoteSharedMugshotProjection: Decodable, Identifiable, Equatable {
    let sharedMugshotID: UUID
    let contextType: String
    let cafeID: UUID?
    let locationLabel: String?
    let occurredAt: String
    let contributions: [RemoteSharedMugshotContribution]

    var id: UUID { sharedMugshotID }

    enum CodingKeys: String, CodingKey {
        case sharedMugshotID = "shared_memory_id"
        case contextType = "context_type"
        case cafeID = "cafe_id"
        case locationLabel = "location_label"
        case occurredAt = "occurred_at"
        case contributions
    }

    var groupedContributions: [RemoteSharedMugshotContribution]? {
        var seenVisitIDs: Set<UUID> = []
        var seenUserIDs: Set<UUID> = []
        let unique = contributions.filter { contribution in
            seenVisitIDs.insert(contribution.visitID).inserted
                && seenUserIDs.insert(contribution.userID).inserted
        }
        return unique.count >= 2 ? unique : nil
    }
}

struct RemoteSharedMugshotContribution: Decodable, Identifiable, Equatable {
    let visitID: UUID
    let userID: UUID
    let displayName: String?
    let username: String
    let avatarURL: String?
    let caption: String?
    let drink: String
    let overallScore: Double
    let posterPhotoURL: String?
    let visibility: String
    let createdAt: String

    var id: UUID { visitID }

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case caption
        case drink
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
        case visibility
        case createdAt = "created_at"
    }

    var personLabel: String {
        displayName?.remoteTrimmedNonEmpty ?? "@\(username)"
    }
}

struct RemoteVisitDetail: Identifiable, Equatable {
    let summary: RemoteVisitSummary
    let photos: [SupabaseVisitPhotoRow]
    let comments: [RemoteVisitComment]
    let likeCount: Int
    let currentUserHasLiked: Bool
    let privateNote: String?
    let sensorySnapshot: SipSensorySnapshot?
    let cafeSessionSummary: RemoteCafeSessionSummary?
    let v3Reflection: V3VisitReflection?
    let recipeProjection: RemoteVisitRecipeProjection?
    let recipeIdentityProjection: RemoteVisitRecipeIdentityProjection?
    let sharedMugshotProjection: RemoteSharedMugshotProjection?
    let taggedAccounts: [RemoteVisitTag]

    init(
        summary: RemoteVisitSummary,
        photos: [SupabaseVisitPhotoRow],
        comments: [RemoteVisitComment],
        likeCount: Int,
        currentUserHasLiked: Bool,
        privateNote: String? = nil,
        sensorySnapshot: SipSensorySnapshot? = nil,
        cafeSessionSummary: RemoteCafeSessionSummary? = nil,
        v3Reflection: V3VisitReflection? = nil,
        recipeProjection: RemoteVisitRecipeProjection? = nil,
        recipeIdentityProjection: RemoteVisitRecipeIdentityProjection? = nil,
        sharedMugshotProjection: RemoteSharedMugshotProjection? = nil,
        taggedAccounts: [RemoteVisitTag] = []
    ) {
        self.summary = summary
        self.photos = photos
        self.comments = comments
        self.likeCount = likeCount
        self.currentUserHasLiked = currentUserHasLiked
        self.privateNote = privateNote
        self.sensorySnapshot = sensorySnapshot
        self.cafeSessionSummary = cafeSessionSummary
        self.v3Reflection = v3Reflection
        self.recipeProjection = recipeProjection
        self.recipeIdentityProjection = recipeIdentityProjection
        self.sharedMugshotProjection = sharedMugshotProjection
        self.taggedAccounts = taggedAccounts
    }

    var id: UUID { summary.id }

    var photoURLs: [String] {
        let storedPhotoURLs = photos
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map(\.photoURL)
            .filter { $0.remoteTrimmedNonEmpty != nil }

        guard let posterPhotoURL = summary.visit.posterPhotoURL?.remoteTrimmedNonEmpty else {
            return storedPhotoURLs
        }

        return [posterPhotoURL] + storedPhotoURLs.filter { $0 != posterPhotoURL }
    }

    var commentCount: Int {
        comments.count
    }
}

private extension String {
    var remoteISO8601Date: Date? {
        RemoteDateParser.date(from: self)
    }
}

private enum RemoteDateParser {
    private static let lock = NSLock()
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from value: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return fractional.date(from: value) ?? standard.date(from: value)
    }
}

struct RemoteVisitV3FeedProjection: Decodable, Equatable {
    let visitID: UUID
    let mugshotScore: Double
    let photoFallbackValue: String?

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case mugshotScore = "mugshot_score"
        case photoFallbackValue = "photo_fallback"
    }

    var usesMugsyPhotoFallback: Bool {
        photoFallbackValue == SipPhotoFallback.mugsyMissedPhoto.rawValue
    }
}

struct RemoteVisitSummary: Identifiable, Equatable {
    let visit: SupabaseVisitRow
    let cafe: SupabaseCafeSummary?
    let author: SupabaseUserProfile?
    let socialState: RemoteVisitSocialState
    let rankingScore: Double?
    let recommendationReason: String?
    let recommendationReasonType: String?
    let sessionSipCount: Int
    let cafePulseProjection: RemoteCafePulseProjection?
    let v3FeedProjection: RemoteVisitV3FeedProjection?

    init(
        visit: SupabaseVisitRow,
        cafe: SupabaseCafeSummary?,
        author: SupabaseUserProfile? = nil,
        socialState: RemoteVisitSocialState = RemoteVisitSocialState(
            likeCount: 0,
            commentCount: 0,
            currentUserHasLiked: false
        ),
        rankingScore: Double? = nil,
        recommendationReason: String? = nil,
        recommendationReasonType: String? = nil,
        sessionSipCount: Int = 1,
        cafePulseProjection: RemoteCafePulseProjection? = nil,
        v3FeedProjection: RemoteVisitV3FeedProjection? = nil
    ) {
        self.visit = visit
        self.cafe = cafe
        self.author = author
        self.socialState = socialState
        self.rankingScore = rankingScore
        self.recommendationReason = recommendationReason
        self.recommendationReasonType = recommendationReasonType
        self.sessionSipCount = max(sessionSipCount, 1)
        self.cafePulseProjection = cafePulseProjection
        self.v3FeedProjection = v3FeedProjection
    }

    var id: UUID { visit.id }

    var locationTitle: String {
        switch visit.journalContext {
        case .cafe:
            return cafe?.consumerDisplayName
                ?? visit.locationName?.remoteTrimmedNonEmpty
                ?? visit.contextDisplayName
        case .home, .elsewhere, .recipe:
            return visit.locationName?.remoteTrimmedNonEmpty
                ?? visit.journalContext.locationFallback
        }
    }

    var locationSubtitle: String? {
        guard visit.journalContext == .cafe else { return nil }
        if let cafe, !cafe.displayLocation.isEmpty {
            return cafe.displayLocation
        }
        return visit.cityState?.remoteTrimmedNonEmpty
    }

    var displayedMugshotScore: Double {
        v3FeedProjection?.mugshotScore ?? visit.overallScore
    }

    var usesMugsyPhotoFallback: Bool {
        v3FeedProjection?.usesMugsyPhotoFallback == true
    }

    var authorDisplayName: String {
        author?.displayName.remoteTrimmedNonEmpty ?? author?.username ?? "Mugshot User"
    }

    var authorUsername: String {
        author?.username ?? "user"
    }

    var authorInitial: String {
        String(authorUsername.prefix(1)).uppercased()
    }

    var additionalSessionSipCount: Int {
        max(sessionSipCount - 1, 0)
    }
}

struct RemoteProfileStats: Equatable {
    let totalVisits: Int
    let totalCafes: Int
    let averageScore: Double
    let favoriteDrinkLabel: String?
    let topCafes: [RemoteTopCafe]

    static let empty = RemoteProfileStats(
        totalVisits: 0,
        totalCafes: 0,
        averageScore: 0,
        favoriteDrinkLabel: nil,
        topCafes: []
    )

    static func calculate(from visits: [RemoteVisitSummary]) -> RemoteProfileStats {
        guard !visits.isEmpty else {
            return .empty
        }

        let totalScore = visits.reduce(0.0) { $0 + $1.visit.overallScore }
        let topCafes = legacyCafeSipAverages(from: visits)

        let favoriteDrinkLabel = Dictionary(grouping: visits, by: { $0.visit.drinkDisplayName })
            .mapValues(\.count)
            .max {
                if $0.value == $1.value {
                    return $0.key > $1.key
                }
                return $0.value < $1.value
            }?
            .key

        return RemoteProfileStats(
            totalVisits: visits.count,
            totalCafes: Set(visits.compactMap { visit in
                visit.visit.journalContext == .cafe ? visit.cafe?.id : nil
            }).count,
            averageScore: totalScore / Double(visits.count),
            favoriteDrinkLabel: favoriteDrinkLabel,
            topCafes: Array(topCafes.prefix(10))
        )
    }

    /// Legacy drink-enjoyment aggregates. These values may be shown only when
    /// explicitly labeled as a Sip average; they are never cafe ratings.
    static func legacyCafeSipAverages(
        from visits: [RemoteVisitSummary]
    ) -> [RemoteTopCafe] {
        let cafesByID = Dictionary(
            grouping: visits.compactMap { visit -> RemoteVisitSummary? in
                guard visit.visit.journalContext == .cafe,
                      visit.cafe != nil else {
                    return nil
                }
                return visit
            },
            by: { $0.cafe!.id }
        )

        return cafesByID.values.compactMap { cafeVisits -> RemoteTopCafe? in
            guard let first = cafeVisits.first, let cafe = first.cafe else {
                return nil
            }

            let averageScore = cafeVisits.reduce(0.0) {
                $0 + $1.visit.overallScore
            } / Double(cafeVisits.count)
            return RemoteTopCafe(
                cafe: cafe,
                visitCount: cafeVisits.count,
                averageScore: averageScore,
                posterPhotoURL: cafeVisits
                    .sorted { $0.visit.createdAtDate > $1.visit.createdAtDate }
                    .compactMap { $0.visit.posterPhotoURL?.remoteTrimmedNonEmpty }
                    .first
            )
        }
        .sorted {
            if abs($0.averageScore - $1.averageScore) < 0.0001 {
                return $0.visitCount > $1.visitCount
            }
            return $0.averageScore > $1.averageScore
        }
    }
}

struct RemoteTopCafe: Identifiable, Equatable {
    let cafe: SupabaseCafeSummary
    let visitCount: Int
    /// Average enjoyment of the drinks logged here, not a cafe rating.
    let averageScore: Double
    let posterPhotoURL: String?

    var id: UUID { cafe.id }
}

/// Presentation-ready Top cafes with an explicit source of truth.
///
/// Once any independently rated Cafe Session exists, only cafe-experience
/// ratings participate in Top cafes. Before that, the legacy fallback remains
/// available but must be labeled as Sip average in the UI.
struct RemoteProfileCafeRanking: Equatable {
    enum Basis: Equatable {
        case cafeExperience
        case sipAverageLegacy
    }

    struct Entry: Identifiable, Equatable {
        let cafe: SupabaseCafeSummary
        let score: Double
        let sipCount: Int
        let ratedCafeSessionCount: Int
        let physicalCafeSessionCount: Int
        let posterPhotoURL: String?

        var id: UUID { cafe.id }
    }

    let basis: Basis
    let entries: [Entry]

    static func calculate(
        from visits: [RemoteVisitSummary],
        cafeExperienceSummaries: [RemoteCafeExperienceSummary],
        limit: Int = 10
    ) -> RemoteProfileCafeRanking {
        let sipAverages = RemoteProfileStats.legacyCafeSipAverages(from: visits)
        let summariesByCafeID = cafeExperienceSummaries.reduce(
            into: [UUID: RemoteCafeExperienceSummary]()
        ) { result, summary in
            result[summary.cafeID] = summary
        }

        let cafeExperienceEntries = sipAverages.compactMap {
            aggregate -> Entry? in
            guard let summary = summariesByCafeID[aggregate.cafe.id],
                  summary.scope == CafeExperienceSummaryScope.personal.rawValue,
                  summary.ratedSessionCount > 0,
                  let averageCafeRating = summary.averageCafeRating,
                  averageCafeRating.isFinite else {
                return nil
            }
            return Entry(
                cafe: aggregate.cafe,
                score: averageCafeRating,
                sipCount: aggregate.visitCount,
                ratedCafeSessionCount: summary.ratedSessionCount,
                physicalCafeSessionCount: summary.physicalSessionCount,
                posterPhotoURL: aggregate.posterPhotoURL
            )
        }

        if !cafeExperienceEntries.isEmpty {
            return RemoteProfileCafeRanking(
                basis: .cafeExperience,
                entries: Array(
                    ordered(cafeExperienceEntries).prefix(max(0, limit))
                )
            )
        }

        let legacyEntries = sipAverages.map {
            Entry(
                cafe: $0.cafe,
                score: $0.averageScore,
                sipCount: $0.visitCount,
                ratedCafeSessionCount: 0,
                physicalCafeSessionCount: 0,
                posterPhotoURL: $0.posterPhotoURL
            )
        }
        return RemoteProfileCafeRanking(
            basis: .sipAverageLegacy,
            entries: Array(ordered(legacyEntries).prefix(max(0, limit)))
        )
    }

    private static func ordered(_ entries: [Entry]) -> [Entry] {
        entries.sorted { lhs, rhs in
            if abs(lhs.score - rhs.score) >= 0.0001 {
                return lhs.score > rhs.score
            }
            if lhs.ratedCafeSessionCount != rhs.ratedCafeSessionCount {
                return lhs.ratedCafeSessionCount > rhs.ratedCafeSessionCount
            }
            if lhs.physicalCafeSessionCount != rhs.physicalCafeSessionCount {
                return lhs.physicalCafeSessionCount > rhs.physicalCafeSessionCount
            }
            if lhs.sipCount != rhs.sipCount {
                return lhs.sipCount > rhs.sipCount
            }
            let leftName = lhs.cafe.consumerDisplayName.lowercased()
            let rightName = rhs.cafe.consumerDisplayName.lowercased()
            if leftName != rightName {
                return leftName < rightName
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

struct RemoteCafeVisitStats: Equatable {
    let visitCount: Int
    let averageScore: Double

    static func calculate(from visits: [RemoteVisitSummary]) -> RemoteCafeVisitStats {
        guard !visits.isEmpty else {
            return RemoteCafeVisitStats(visitCount: 0, averageScore: 0)
        }

        let total = visits.reduce(0.0) { $0 + $1.visit.overallScore }
        return RemoteCafeVisitStats(
            visitCount: visits.count,
            averageScore: total / Double(visits.count)
        )
    }
}

extension String {
    var remoteTrimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
