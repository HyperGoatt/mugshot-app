import CoreLocation
import Foundation

struct PublicCafeListLinkRoute: Identifiable, Equatable {
    let slug: String
    var id: String { slug }

    static func resolve(
        _ url: URL,
        publicBaseURL: URL? = MugshotShareConfiguration.load().publicBaseURL
    ) -> PublicCafeListLinkRoute? {
        var pathParts = url.pathComponents.filter { $0 != "/" }
        if url.scheme?.lowercased() == "mugshot", let host = url.host {
            pathParts.insert(host, at: 0)
        }
        guard pathParts.count == 2,
              pathParts[0].lowercased() == "l",
              isValidSlug(pathParts[1]) else { return nil }
        if url.scheme?.lowercased() == "mugshot" {
            return PublicCafeListLinkRoute(slug: pathParts[1])
        }
        guard let publicBaseURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == publicBaseURL.host?.lowercased() else { return nil }
        return PublicCafeListLinkRoute(slug: pathParts[1])
    }

    static func isValidSlug(_ slug: String) -> Bool {
        slug.count == 24 && slug.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

struct PublicCafeList: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let visibility: CafeListVisibility
    let publishedAt: String
    let updatedAt: String
    let commentsEnabled: Bool
    let creator: CafeListPerson
    let contributors: [CafeListPerson]
    let cafeCount: Int
    let followerCount: Int
    var isFollowing: Bool
    let canComment: Bool
    let slug: String
    let inspiredBy: PublicCafeListInspiration?
    let items: [PublicCafeListItem]?
    let comments: [PublicCafeListComment]?

    enum CodingKeys: String, CodingKey {
        case id, title, description, visibility, creator, contributors, slug, items, comments
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
        case commentsEnabled = "comments_enabled"
        case cafeCount = "cafe_count"
        case followerCount = "follower_count"
        case isFollowing = "is_following"
        case canComment = "can_comment"
        case inspiredBy = "inspired_by"
    }

    var resolvedItems: [PublicCafeListItem] { items ?? [] }
    var resolvedComments: [PublicCafeListComment] { comments ?? [] }
}

struct PublicCafeListInspiration: Codable, Equatable {
    let listID: UUID
    let title: String
    let creator: CafeListPerson

    enum CodingKeys: String, CodingKey {
        case title, creator
        case listID = "list_id"
    }
}

struct PublicCafeListItem: Identifiable, Codable, Equatable {
    let id: UUID
    let cafeID: UUID
    let position: Int
    let caption: String?
    let cafeName: String
    let cafeAddress: String?
    let cafeCity: String?
    let latitude: Double?
    let longitude: Double?
    let appleMapsPlaceID: String?
    let legacyApplePlaceID: String?
    let websiteURL: String?
    let photoURL: String?
    let contributor: CafeListPerson

    enum CodingKeys: String, CodingKey {
        case id, position, caption, latitude, longitude, contributor
        case cafeID = "cafe_id"
        case cafeName = "cafe_name"
        case cafeAddress = "cafe_address"
        case cafeCity = "cafe_city"
        case appleMapsPlaceID = "apple_maps_place_id"
        case legacyApplePlaceID = "apple_place_id"
        case websiteURL = "website_url"
        case photoURL = "photo_url"
    }

    var localCafe: Cafe {
        Cafe(
            id: cafeID,
            name: cafeName,
            location: coordinate,
            address: cafeAddress?.remoteTrimmedNonEmpty ?? cafeCity?.remoteTrimmedNonEmpty ?? "",
            appleMapsPlaceID: appleMapsPlaceID,
            mapItemURL: legacyApplePlaceID,
            websiteURL: websiteURL,
            remoteCafeId: cafeID
        )
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude,
              CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude)) else {
            return nil
        }
        return .init(latitude: latitude, longitude: longitude)
    }
}

struct PublicCafeListComment: Identifiable, Codable, Equatable {
    let id: UUID
    let body: String
    let createdAt: String
    let author: CafeListPerson
    let canDelete: Bool

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case createdAt = "created_at"
        case canDelete = "can_delete"
    }
}
