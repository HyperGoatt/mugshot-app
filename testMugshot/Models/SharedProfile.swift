import Foundation

struct SharedProfileProjection: Decodable, Equatable {
    let profile: SupabaseUserProfile
    let friendshipState: FriendshipState
    let stats: SharedProfileStats
    let highlight: SharedProfileHighlight?
    let topCafes: [SharedProfileTopCafe]
    let tastePassportVisible: Bool
    let tastePassport: TastePassportProjection?
    let viewerProjection: String

    enum CodingKeys: String, CodingKey {
        case profile, stats, highlight
        case friendshipState = "friendship_state"
        case topCafes = "top_cafes"
        case tastePassportVisible = "taste_passport_visible"
        case tastePassport = "taste_passport"
        case viewerProjection = "viewer_projection"
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
