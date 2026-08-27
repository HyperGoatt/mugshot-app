import CoreLocation
import Foundation

struct SharedProfileProjection: Decodable, Equatable {
    let profile: SupabaseUserProfile
    let friendshipState: FriendshipState
    let stats: SharedProfileStats
    let highlight: SharedProfileHighlight?
    let favoriteSpots: [SharedProfileFavoriteSpot]
    let topCafes: [SharedProfileTopCafe]
    let tastePassportVisible: Bool
    let tastePassport: TastePassportProjection?
    let viewerProjection: String
    let profileContractVersion: Int

    enum CodingKeys: String, CodingKey {
        case profile, stats, highlight
        case favoriteSpots = "favorite_spots"
        case friendshipState = "friendship_state"
        case topCafes = "top_cafes"
        case tastePassportVisible = "taste_passport_visible"
        case tastePassport = "taste_passport"
        case viewerProjection = "viewer_projection"
        case profileContractVersion = "profile_contract_version"
    }

    init(
        profile: SupabaseUserProfile,
        friendshipState: FriendshipState,
        stats: SharedProfileStats,
        highlight: SharedProfileHighlight? = nil,
        favoriteSpots: [SharedProfileFavoriteSpot] = [],
        topCafes: [SharedProfileTopCafe] = [],
        tastePassportVisible: Bool = false,
        tastePassport: TastePassportProjection? = nil,
        viewerProjection: String = "signed_in",
        profileContractVersion: Int = 4
    ) {
        self.profile = profile
        self.friendshipState = friendshipState
        self.stats = stats
        self.highlight = highlight
        self.favoriteSpots = favoriteSpots
        self.topCafes = topCafes
        self.tastePassportVisible = tastePassportVisible
        self.tastePassport = tastePassport
        self.viewerProjection = viewerProjection
        self.profileContractVersion = profileContractVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(SupabaseUserProfile.self, forKey: .profile)
        friendshipState = try container.decode(FriendshipState.self, forKey: .friendshipState)
        stats = try container.decode(SharedProfileStats.self, forKey: .stats)
        highlight = try container.decodeIfPresent(SharedProfileHighlight.self, forKey: .highlight)
        favoriteSpots = try container.decodeIfPresent(
            [SharedProfileFavoriteSpot].self,
            forKey: .favoriteSpots
        ) ?? []
        topCafes = try container.decodeIfPresent([SharedProfileTopCafe].self, forKey: .topCafes) ?? []
        tastePassportVisible = try container.decodeIfPresent(Bool.self, forKey: .tastePassportVisible) ?? false
        tastePassport = try container.decodeIfPresent(TastePassportProjection.self, forKey: .tastePassport)
        viewerProjection = try container.decodeIfPresent(String.self, forKey: .viewerProjection) ?? "signed_in"
        profileContractVersion = try container.decodeIfPresent(Int.self, forKey: .profileContractVersion) ?? 1
    }
}

struct SharedProfileStats: Decodable, Equatable {
    let friends: Int
    let sips: Int
    let cafes: Int
}

struct SharedProfileHighlight: Decodable, Equatable {
    let type: String
    let sip: SharedProfileHighlightSip?
    let cafe: SharedProfileHighlightCafe?
}

struct SharedProfileHighlightSip: Decodable, Equatable {
    let id: UUID
    let caption: String?
    let drinkName: String
    let score: Double
    let coverPhotoURL: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, caption, score
        case drinkName = "drink_name"
        case coverPhotoURL = "cover_photo_url"
        case createdAt = "created_at"
    }
}

struct SharedProfileHighlightCafe: Decodable, Equatable {
    let id: UUID
    let name: String
    let city: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let identityKey: String?
    let coverPhotoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, city, address, latitude, longitude
        case identityKey = "identity_key"
        case coverPhotoURL = "cover_photo_url"
    }
}

struct SharedProfileFavoriteSpot: Decodable, Equatable, Identifiable {
    let position: Int
    let descriptor: String
    let cafeID: UUID
    let name: String
    let city: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let identityKey: String?
    let coverPhotoURL: String?

    var id: UUID { cafeID }

    enum CodingKeys: String, CodingKey {
        case position, descriptor, name, city, address, latitude, longitude
        case cafeID = "cafe_id"
        case identityKey = "identity_key"
        case coverPhotoURL = "cover_photo_url"
    }

    var localCafe: Cafe {
        Cafe(
            id: cafeID,
            name: name,
            location: latitude.flatMap { latitude in
                longitude.map { longitude in
                    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                }
            },
            address: address ?? city ?? "",
            remoteCafeId: cafeID
        )
    }
}

struct SharedProfilePublicCafe: Decodable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let city: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let identityKey: String?
    let score: Double
    let evidenceCount: Int
    let sipCount: Int
    let coverPhotoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, city, address, latitude, longitude, score
        case identityKey = "identity_key"
        case evidenceCount = "evidence_count"
        case sipCount = "sip_count"
        case coverPhotoURL = "cover_photo_url"
    }

    var localCafe: Cafe {
        Cafe(
            id: id,
            name: name,
            location: latitude.flatMap { latitude in
                longitude.map { longitude in
                    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                }
            },
            address: address ?? city ?? "",
            averageRating: score,
            visitCount: sipCount,
            remoteCafeId: id
        )
    }
}

struct SharedProfileFriend: Decodable, Equatable, Identifiable {
    let relationshipID: UUID
    let userID: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let createdAt: String
    let friendshipState: FriendshipState

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case relationshipID = "relationship_id"
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case friendshipState = "friendship_state"
    }

}

struct ProfileFavoriteSpotInput: Encodable, Equatable {
    let cafeID: UUID
    let descriptor: String

    enum CodingKeys: String, CodingKey {
        case cafeID = "cafe_id"
        case descriptor
    }
}

enum ProfileFavoriteSpotPolicy {
    static let maximumCount = 3
    static let descriptorLimit = 30

    static func normalizedDescriptor(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= descriptorLimit else { return nil }
        return normalized
    }

    static func validated(_ inputs: [ProfileFavoriteSpotInput]) -> [ProfileFavoriteSpotInput]? {
        guard inputs.count <= maximumCount,
              Set(inputs.map(\.cafeID)).count == inputs.count else { return nil }
        let normalized = inputs.compactMap { input -> ProfileFavoriteSpotInput? in
            guard let descriptor = normalizedDescriptor(input.descriptor) else { return nil }
            return ProfileFavoriteSpotInput(cafeID: input.cafeID, descriptor: descriptor)
        }
        return normalized.count == inputs.count ? normalized : nil
    }
}

enum SharedProfileTab: String, CaseIterable, Identifiable {
    case mugshots
    case cafes
    case map
    case tagged

    var id: String { rawValue }

    var accessibilityTitle: String {
        switch self {
        case .mugshots: "Public Mugshots"
        case .cafes: "Public cafes"
        case .map: "Public exploration map"
        case .tagged: "Tagged Mugshots"
        }
    }

    var systemImage: String {
        switch self {
        case .mugshots: "rectangle.grid.2x2"
        case .cafes: "storefront"
        case .map: "map"
        case .tagged: "person.crop.rectangle"
        }
    }
}

enum ProfileSpotDescriptorCategory: String, CaseIterable, Identifiable {
    case drink = "Drink"
    case vibe = "Vibe"
    case food = "Food"
    case occasion = "Occasion"
    case service = "Service"
    case custom = "Make it yours"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .drink: "cup.and.saucer.fill"
        case .vibe: "sparkles"
        case .food: "fork.knife"
        case .occasion: "calendar"
        case .service: "person.crop.circle.badge.checkmark"
        case .custom: "pencil"
        }
    }

    var suggestions: [String] {
        switch self {
        case .drink:
            ["Best coffee", "Best espresso", "Best matcha", "Best fun drinks", "Best seasonal drinks", "Best tea"]
        case .vibe:
            ["Best hang", "Work remote", "Date spot", "Group hang", "Quiet morning", "Best patio"]
        case .food:
            ["Best pastries", "Best brunch", "Best breakfast", "Best lunch", "Best sweet treat"]
        case .occasion:
            ["Worth the trip", "Neighborhood favorite", "Quick stop", "Treat yourself", "Best value"]
        case .service:
            ["Best service", "Warmest welcome", "They know my order", "Always reliable"]
        case .custom:
            []
        }
    }

    static func category(containing descriptor: String?) -> ProfileSpotDescriptorCategory {
        guard let descriptor else { return .drink }
        return allCases.first(where: { $0.suggestions.contains(descriptor) }) ?? .custom
    }
}

struct SharedProfileTopCafe: Decodable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let city: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let identityKey: String?
    let score: Double
    let basis: String
    let evidenceCount: Int
    let sipCount: Int
    let coverPhotoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, city, address, latitude, longitude, score, basis
        case identityKey = "identity_key"
        case evidenceCount = "evidence_count"
        case sipCount = "sip_count"
        case coverPhotoURL = "cover_photo_url"
    }
}

struct MugshotProfileSharedLinkRoute: Identifiable, Equatable {
    let slug: String
    var id: String { slug }

    static func resolve(
        _ url: URL,
        publicBaseURL: URL? = MugshotShareConfiguration.load().publicBaseURL
    ) -> MugshotProfileSharedLinkRoute? {
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme?.lowercased() == "mugshot", let host = url.host {
            parts.insert(host, at: 0)
        }
        guard parts.count == 2,
              parts[0].lowercased() == "p",
              MugshotSharedLinkRoute.isValidSlug(parts[1]) else { return nil }
        if url.scheme?.lowercased() == "mugshot" {
            return MugshotProfileSharedLinkRoute(slug: parts[1])
        }
        guard let publicBaseURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == publicBaseURL.host?.lowercased() else { return nil }
        return MugshotProfileSharedLinkRoute(slug: parts[1])
    }
}
