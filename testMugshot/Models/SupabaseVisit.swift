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
    let notes: String?
    let visibility: String
    let uploadState: String
    let ratings: [String: Double]
    let overallScore: Double
    let posterPhotoURL: String?
    let contextType: String?
    let locationName: String?
    let cityState: String?
    let brewMethod: String?
    let equipment: String?
    let brewDetails: BrewDetails?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cafeId = "cafe_id"
        case drinkType = "drink_type"
        case drinkTypeCustom = "drink_type_custom"
        case drinkSubtype = "drink_subtype"
        case caption
        case notes
        case visibility
        case uploadState = "upload_state"
        case ratings
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
        case contextType = "context_type"
        case locationName = "location_name"
        case cityState = "city_state"
        case brewMethod = "brew_method"
        case equipment
        case brewDetails = "brew_details"
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
        overallScore: Double,
        posterPhotoURL: String?,
        contextType: String?,
        locationName: String?,
        cityState: String?,
        brewMethod: String?,
        createdAt: String,
        equipment: String? = nil,
        brewDetails: BrewDetails? = nil
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
        self.overallScore = overallScore
        self.posterPhotoURL = posterPhotoURL
        self.contextType = contextType
        self.locationName = locationName
        self.cityState = cityState
        self.brewMethod = brewMethod
        self.equipment = equipment
        self.brewDetails = brewDetails
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
           brewDetails?.recipeName?.remoteTrimmedNonEmpty != nil {
            return .recipe
        }
        return JournalEntryContext(backendValue: contextType)
    }

    var structuredBrewDetails: BrewDetails {
        brewDetails ?? .empty
    }

    var trimmedNotes: String? {
        notes?.remoteTrimmedNonEmpty
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
    let notes: String?
    let visibility: String

    static func make(
        caption: String,
        notes: String?,
        visibility: VisitVisibility
    ) throws -> SupabaseVisitUpdate {
        guard let trimmedCaption = caption.remoteTrimmedNonEmpty else {
            throw VisitServiceError.emptyCaption
        }

        return SupabaseVisitUpdate(
            caption: trimmedCaption,
            notes: notes?.remoteTrimmedNonEmpty,
            visibility: visibility.supabaseValue
        )
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

struct RemoteVisitDetail: Identifiable, Equatable {
    let summary: RemoteVisitSummary
    let photos: [SupabaseVisitPhotoRow]
    let comments: [RemoteVisitComment]
    let likeCount: Int
    let currentUserHasLiked: Bool

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

        if storedPhotoURLs.contains(posterPhotoURL) {
            return storedPhotoURLs
        }

        return [posterPhotoURL] + storedPhotoURLs
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

struct RemoteVisitSummary: Identifiable, Equatable {
    let visit: SupabaseVisitRow
    let cafe: SupabaseCafeSummary?
    let author: SupabaseUserProfile?
    let socialState: RemoteVisitSocialState
    let rankingScore: Double?

    init(
        visit: SupabaseVisitRow,
        cafe: SupabaseCafeSummary?,
        author: SupabaseUserProfile? = nil,
        socialState: RemoteVisitSocialState = RemoteVisitSocialState(
            likeCount: 0,
            commentCount: 0,
            currentUserHasLiked: false
        ),
        rankingScore: Double? = nil
    ) {
        self.visit = visit
        self.cafe = cafe
        self.author = author
        self.socialState = socialState
        self.rankingScore = rankingScore
    }

    var id: UUID { visit.id }

    var locationTitle: String {
        if let cafe {
            return cafe.consumerDisplayName
        }
        if let locationName = visit.locationName?.remoteTrimmedNonEmpty {
            return locationName
        }
        return visit.contextDisplayName
    }

    var locationSubtitle: String? {
        if let cafe, !cafe.displayLocation.isEmpty {
            return cafe.displayLocation
        }
        return visit.cityState?.remoteTrimmedNonEmpty
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
        let cafesById = Dictionary(grouping: visits.compactMap { visit -> RemoteVisitSummary? in
            visit.cafe == nil ? nil : visit
        }) { $0.cafe!.id }

        let topCafes = cafesById.values.compactMap { cafeVisits -> RemoteTopCafe? in
            guard let first = cafeVisits.first, let cafe = first.cafe else {
                return nil
            }

            let averageScore = cafeVisits.reduce(0.0) { $0 + $1.visit.overallScore } / Double(cafeVisits.count)
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
            totalCafes: Set(visits.compactMap { $0.cafe?.id }).count,
            averageScore: totalScore / Double(visits.count),
            favoriteDrinkLabel: favoriteDrinkLabel,
            topCafes: Array(topCafes.prefix(10))
        )
    }
}

struct RemoteTopCafe: Identifiable, Equatable {
    let cafe: SupabaseCafeSummary
    let visitCount: Int
    let averageScore: Double
    let posterPhotoURL: String?

    var id: UUID { cafe.id }
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
