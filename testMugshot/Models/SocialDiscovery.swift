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

struct SipCompanionSuggestion: Identifiable, Decodable, Equatable {
    let userID: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let sharedSipCount: Int
    let lastSharedAt: String?

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case sharedSipCount = "shared_sip_count"
        case lastSharedAt = "last_shared_at"
    }

    var companion: SipCompanion {
        SipCompanion(
            userID: userID,
            displayName: displayName,
            username: username,
            avatarURL: avatarURL
        )
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

struct DiscoveryCafeFriend: Identifiable, Decodable, Equatable {
    let userID: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let averageRating: Double
    let sipCount: Int

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case username
        case userID = "user_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case averageRating = "average_rating"
        case sipCount = "sip_count"
    }
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
    let friendProfiles: [DiscoveryCafeFriend]?

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
        case friendProfiles = "friend_profiles"
    }

    var friends: [DiscoveryCafeFriend] { friendProfiles ?? [] }

    var localCafe: Cafe {
        remoteCafe.localCafe(
            isFavorite: isSaved,
            wantToTry: isSaved && !isVisited,
            // Discovery v1's average is built from sip enjoyment. Keep the
            // place unrated until a Cafe Pulse aggregate is available.
            averageRating: 0,
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
    let rankingReason: String?
    let reasonType: String?

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case feedScore = "feed_score"
        case createdAt = "created_at"
        case rankingReason = "ranking_reason"
        case reasonType = "reason_type"
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
    let homeSips: Int?
    let recipeSips: Int?

    enum CodingKeys: String, CodingKey {
        case friends, cafes
        case visibleVisits = "visible_visits"
        case homeSips = "home_sips"
        case recipeSips = "recipe_sips"
    }
}

struct PublicProfileVisit: Identifiable, Decodable, Equatable {
    let id: UUID
    let userID: UUID?
    let cafeID: UUID?
    let caption: String
    let drinkType: String?
    let drinkTypeCustom: String?
    let drinkSubtype: String?
    let visibility: String?
    let ratings: [String: Double]?
    let overallScore: Double
    let posterPhotoURL: String?
    let photoURLs: [String]?
    let contextType: String?
    let locationName: String?
    let createdAt: String
    let cafeName: String?
    let cafeCity: String?
    let latitude: Double?
    let longitude: Double?
    let identityKey: String?
    let authorDisplayName: String?
    let authorUsername: String?
    let authorAvatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, caption, latitude, longitude
        case userID = "user_id"
        case cafeID = "cafe_id"
        case drinkType = "drink_type"
        case drinkTypeCustom = "drink_type_custom"
        case drinkSubtype = "drink_subtype"
        case visibility, ratings
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
        case photoURLs = "photo_urls"
        case contextType = "context_type"
        case locationName = "location_name"
        case createdAt = "created_at"
        case cafeName = "cafe_name"
        case cafeCity = "cafe_city"
        case identityKey = "identity_key"
        case authorDisplayName = "author_display_name"
        case authorUsername = "author_username"
        case authorAvatarURL = "author_avatar_url"
    }

    var isStrictlyPublic: Bool {
        visibility?.caseInsensitiveCompare("everyone") == .orderedSame
    }

    var isPublishedOnProfile: Bool {
        guard let visibility else { return false }
        return visibility.caseInsensitiveCompare("everyone") == .orderedSame
            || visibility.caseInsensitiveCompare("friends") == .orderedSame
    }

    var journalContext: JournalEntryContext {
        JournalEntryContext(backendValue: contextType)
    }

    var drinkDisplayName: String {
        drinkSubtype?.remoteTrimmedNonEmpty
            ?? drinkTypeCustom?.remoteTrimmedNonEmpty
            ?? drinkType?.remoteTrimmedNonEmpty
            ?? "Drink"
    }

    var cafe: Cafe? {
        guard journalContext == .cafe,
              let cafeID,
              let cafeName else { return nil }
        return SupabaseCafeSummary(
            id: cafeID,
            name: cafeName,
            address: nil,
            city: cafeCity,
            latitude: latitude,
            longitude: longitude,
            applePlaceId: nil,
            websiteURL: nil,
            identityKey: identityKey
        ).localCafe(averageRating: overallScore, visitCount: 1)
    }

    func summary(profile: SupabaseUserProfile) -> RemoteVisitSummary {
        let resolvedProfile: SupabaseUserProfile
        if let userID,
           let authorUsername = authorUsername?.remoteTrimmedNonEmpty {
            resolvedProfile = SupabaseUserProfile(
                id: userID,
                displayName: authorDisplayName?.remoteTrimmedNonEmpty ?? "@\(authorUsername)",
                username: authorUsername,
                bio: nil,
                location: nil,
                favoriteDrink: nil,
                instagramHandle: nil,
                avatarURL: authorAvatarURL,
                bannerURL: nil,
                websiteURL: nil
            )
        } else {
            resolvedProfile = profile
        }
        let remoteCafe = journalContext == .cafe ? cafeID.map { id in
            SupabaseCafeSummary(
                id: id,
                name: cafeName ?? "Cafe",
                address: nil,
                city: cafeCity,
                latitude: latitude,
                longitude: longitude,
                applePlaceId: nil,
                websiteURL: nil,
                identityKey: identityKey
            )
        } : nil
        let row = SupabaseVisitRow(
            id: id,
            userId: userID ?? resolvedProfile.id,
            cafeId: cafeID,
            drinkType: drinkType,
            drinkTypeCustom: drinkTypeCustom,
            drinkSubtype: drinkSubtype,
            caption: caption,
            notes: nil,
            visibility: visibility ?? "everyone",
            ratings: ratings ?? [:],
            overallScore: overallScore,
            posterPhotoURL: posterPhotoURL,
            contextType: contextType,
            locationName: locationName,
            cityState: cafeCity,
            brewMethod: nil,
            createdAt: createdAt
        )
        return RemoteVisitSummary(visit: row, cafe: remoteCafe, author: resolvedProfile)
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

enum CafeListVisibility: String, Codable, CaseIterable, Identifiable {
    case `private`
    case friends
    case invited
    case `public`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .private: "Private"
        case .friends: "Friends"
        case .invited: "Invited only"
        case .public: "Public"
        }
    }
}

struct CafeListRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let ownerID: UUID
    let title: String
    let description: String?
    let visibility: CafeListVisibility
    let systemKind: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, visibility
        case ownerID = "owner_id"
        case systemKind = "system_kind"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CafeListItemRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let listID: UUID
    let cafeID: UUID
    let position: Int
    let contributorID: UUID
    let note: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, position, note
        case listID = "list_id"
        case cafeID = "cafe_id"
        case contributorID = "contributor_id"
        case createdAt = "created_at"
    }
}

struct CafeListMemberRecord: Codable, Equatable {
    let listID: UUID
    let userID: UUID
    let role: String
    let invitationStatus: String
    let invitedBy: UUID
    let createdAt: String
    let acceptedAt: String?

    enum CodingKeys: String, CodingKey {
        case role
        case listID = "list_id"
        case userID = "user_id"
        case invitationStatus = "invitation_status"
        case invitedBy = "invited_by"
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
    }
}

enum TrustedRecommendationKind: String, Codable, CaseIterable {
    case cafe
    case visit
    case recipe
}

struct TrustedRecommendation: Identifiable, Codable, Equatable {
    let id: UUID
    let senderID: UUID
    let recipientID: UUID
    let targetKind: TrustedRecommendationKind
    let targetCafeID: UUID?
    let targetVisitID: UUID?
    let targetRecipeVersionID: UUID?
    let note: String?
    let status: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, note, status
        case senderID = "sender_id"
        case recipientID = "recipient_id"
        case targetKind = "target_kind"
        case targetCafeID = "target_cafe_id"
        case targetVisitID = "target_visit_id"
        case targetRecipeVersionID = "target_recipe_version_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SharedRecipeRecord: Identifiable, Decodable, Equatable {
    let recommendationID: UUID
    let recipeIdentityID: UUID
    let recipeVersionID: UUID
    let recipeName: String
    let versionNumber: Int
    let versionLabel: String?
    let brewDetails: BrewDetails
    let senderID: UUID
    let note: String?
    let sharedAt: String

    var id: UUID { recommendationID }

    enum CodingKeys: String, CodingKey {
        case note
        case recommendationID = "recommendation_id"
        case recipeIdentityID = "recipe_identity_id"
        case recipeVersionID = "recipe_version_id"
        case recipeName = "recipe_name"
        case versionNumber = "version_number"
        case versionLabel = "version_label"
        case brewDetails = "brew_details"
        case senderID = "sender_id"
        case sharedAt = "shared_at"
    }
}

struct FriendCompatibility: Decodable, Equatable {
    let evidenceLevel: String
    let sharedSignalCount: Int
    let sharedAttributes: [String]
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case explanation
        case evidenceLevel = "evidence_level"
        case sharedSignalCount = "shared_signal_count"
        case sharedAttributes = "shared_attributes"
    }

    var title: String {
        switch evidenceLevel {
        case "strong_overlap": "Strong taste overlap"
        case "some_overlap": "Some taste overlap"
        default: "Still learning together"
        }
    }
}

enum SipReaction: String, Codable, CaseIterable, Identifiable {
    case wantToTry = "want_to_try"
    case greatFind = "great_find"
    case dialedIn = "dialed_in"
    case cozy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wantToTry: "Want to try"
        case .greatFind: "Great find"
        case .dialedIn: "Dialed in"
        case .cozy: "Cozy"
        }
    }

    var systemImage: String {
        switch self {
        case .wantToTry: "bookmark"
        case .greatFind: "sparkles"
        case .dialedIn: "scope"
        case .cozy: "cup.and.saucer"
        }
    }
}

struct SipReactionRecord: Codable, Equatable {
    let visitID: UUID
    let userID: UUID
    let reaction: SipReaction

    enum CodingKeys: String, CodingKey {
        case reaction
        case visitID = "visit_id"
        case userID = "user_id"
    }
}
