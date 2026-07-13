import Foundation

enum FriendshipState: String, Codable, CaseIterable, Hashable {
    case none
    case incoming
    case outgoing
    case friends
    case blocked
    case `self`
}

struct PeopleSearchResult: Identifiable, Decodable, Equatable {
    let id: UUID
    let displayName: String
    let username: String
    let bio: String?
    let location: String?
    let favoriteDrink: String?
    let avatarURL: String?
    let bannerURL: String?
    let friendshipState: FriendshipState
    let mutualFriendCount: Int
    let rankBucket: Int
    let matchScore: Double

    enum CodingKeys: String, CodingKey {
        case id, username, bio, location
        case displayName = "display_name"
        case favoriteDrink = "favorite_drink"
        case avatarURL = "avatar_url"
        case bannerURL = "banner_url"
        case friendshipState = "friendship_state"
        case mutualFriendCount = "mutual_friend_count"
        case rankBucket = "rank_bucket"
        case matchScore = "match_score"
    }
}

struct SocialConnection: Identifiable, Decodable, Equatable {
    let relationshipID: UUID
    let userID: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let createdAt: String
    let kind: String

    var id: UUID { relationshipID }

    enum CodingKeys: String, CodingKey {
        case relationshipID = "relationship_id"
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case kind
    }
}

enum DiscoverySection: String, CaseIterable, Identifiable {
    case nearby
    case lovedByFriends = "loved_by_friends"
    case popularDrinks = "popular_drinks"
    case trending
    case saved
    case visited

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nearby: "Nearby"
        case .lovedByFriends: "Loved by Friends"
        case .popularDrinks: "Popular Drinks"
        case .trending: "Trending"
        case .saved: "Saved"
        case .visited: "Visited"
        }
    }
}

struct DiscoveryDrink: Decodable, Equatable, Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct DiscoveryCafe: Identifiable, Decodable, Equatable {
    let cafeID: UUID
    let name: String
    let address: String?
    let city: String?
    let latitude: Double
    let longitude: Double
    let identityKey: String
    let section: String
    let rankingScore: Double
    let rankingReason: String
    let distanceKM: Double?
    let averageRating: Double?
    let visibleVisitCount: Int
    let friendCount: Int
    let topDrinks: [DiscoveryDrink]
    let recentCover: String?
    let isSaved: Bool
    let isVisited: Bool

    var id: UUID { cafeID }

    enum CodingKeys: String, CodingKey {
        case name, address, city, latitude, longitude, section
        case cafeID = "cafe_id"
        case identityKey = "identity_key"
        case rankingScore = "ranking_score"
        case rankingReason = "ranking_reason"
        case distanceKM = "distance_km"
        case averageRating = "average_rating"
        case visibleVisitCount = "visible_visit_count"
        case friendCount = "friend_count"
        case topDrinks = "top_drinks"
        case recentCover = "recent_cover"
        case isSaved = "is_saved"
        case isVisited = "is_visited"
    }

    var localCafe: Cafe {
        remoteCafe.localCafe(
            isFavorite: isSaved,
            wantToTry: isSaved && !isVisited,
            averageRating: averageRating ?? 0,
            visitCount: visibleVisitCount
        )
    }

    var remoteCafe: SupabaseCafeSummary {
        SupabaseCafeSummary(
            id: cafeID,
            name: name,
            address: address,
            city: city,
            latitude: latitude,
            longitude: longitude,
            applePlaceId: nil,
            websiteURL: nil,
            identityKey: identityKey
        )
    }
}

struct RankedFeedReference: Decodable, Equatable {
    let visitID: UUID
    let feedScore: Double
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case feedScore = "feed_score"
        case createdAt = "created_at"
    }
}

struct PublicProfilePayload: Decodable, Equatable {
    let profile: SupabaseUserProfile
    let friendshipState: FriendshipState
    let stats: PublicProfileStats
    let visits: [PublicProfileVisit]

    enum CodingKeys: String, CodingKey {
        case profile, stats, visits
        case friendshipState = "friendship_state"
    }
}

struct PublicProfileStats: Decodable, Equatable {
    let visibleVisits: Int
    let friends: Int
    let cafes: Int

    enum CodingKeys: String, CodingKey {
        case friends, cafes
        case visibleVisits = "visible_visits"
    }
}

struct PublicProfileVisit: Identifiable, Decodable, Equatable {
    let id: UUID
    let cafeID: UUID
    let caption: String
    let drinkType: String?
    let drinkSubtype: String?
    let overallScore: Double
    let posterPhotoURL: String?
    let createdAt: String
    let cafeName: String
    let latitude: Double
    let longitude: Double
    let identityKey: String

    enum CodingKeys: String, CodingKey {
        case id, caption, latitude, longitude
        case cafeID = "cafe_id"
        case drinkType = "drink_type"
        case drinkSubtype = "drink_subtype"
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
        case createdAt = "created_at"
        case cafeName = "cafe_name"
        case identityKey = "identity_key"
    }

    var cafe: Cafe {
        SupabaseCafeSummary(
            id: cafeID,
            name: cafeName,
            address: nil,
            city: nil,
            latitude: latitude,
            longitude: longitude,
            applePlaceId: nil,
            websiteURL: nil,
            identityKey: identityKey
        ).localCafe(averageRating: overallScore, visitCount: 1)
    }
}

enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case inappropriateContent = "inappropriate_content"
    case impersonation
    case privacy
    case other

    var id: String { rawValue }
    var title: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
}
