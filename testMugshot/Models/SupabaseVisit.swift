//
//  SupabaseVisit.swift
//  testMugshot
//

import Foundation

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
    let ratings: [String: Double]
    let overallScore: Double
    let posterPhotoURL: String?
    let contextType: String?
    let locationName: String?
    let cityState: String?
    let brewMethod: String?
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
        case ratings
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
        case contextType = "context_type"
        case locationName = "location_name"
        case cityState = "city_state"
        case brewMethod = "brew_method"
        case createdAt = "created_at"
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
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: self) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: self)
    }
}

struct RemoteVisitSummary: Identifiable, Equatable {
    let visit: SupabaseVisitRow
    let cafe: SupabaseCafeSummary?
    let author: SupabaseUserProfile?

    init(
        visit: SupabaseVisitRow,
        cafe: SupabaseCafeSummary?,
        author: SupabaseUserProfile? = nil
    ) {
        self.visit = visit
        self.cafe = cafe
        self.author = author
    }

    var id: UUID { visit.id }

    var locationTitle: String {
        if let cafe {
            return cafe.name
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
