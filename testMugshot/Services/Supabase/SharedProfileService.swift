import Foundation
import Supabase

final class SharedProfileService {
    private let client: SupabaseClient
    private let configuration: MugshotShareConfiguration

    init(
        client: SupabaseClient,
        configuration: MugshotShareConfiguration = .load()
    ) {
        self.client = client
        self.configuration = configuration
    }

    func projection(userID: UUID, asEveryone: Bool = false) async throws -> SharedProfileProjection {
        do {
            return try await client.rpc(
                "get_profile_projection_v4",
                params: ["p_user_id": userID]
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            let parameters = ProfileProjectionParameters(
                userID: userID,
                asEveryone: asEveryone && client.auth.currentUser?.id == userID
            )
            do {
                return try await client.rpc(
                    "get_profile_projection_v3",
                    params: parameters
                ).execute().value
            } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                return try await client.rpc(
                    "get_profile_projection_v2",
                    params: parameters
                ).execute().value
            }
        }
    }

    func sharedProjection(slug: String) async throws -> SharedProfileProjection? {
        guard MugshotSharedLinkRoute.isValidSlug(slug) else { return nil }
        do {
            return try await client.rpc(
                "get_profile_share_v3",
                params: ["p_slug": slug]
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            do {
                return try await client.rpc(
                    "get_profile_share_v2",
                    params: ["p_slug": slug]
                ).execute().value
            } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                return try await client.rpc(
                    "get_profile_share_v1",
                    params: ["p_slug": slug]
                ).execute().value
            }
        }
    }

    func publicSips(
        userID: UUID,
        afterCreatedAt: String? = nil,
        afterID: UUID? = nil,
        limit: Int = 24
    ) async throws -> [PublicProfileVisit] {
        do {
            let visits: [PublicProfileVisit] = try await client.rpc(
                "list_profile_public_sips_v1",
                params: PublicProfilePageParameters(
                    userID: userID,
                    limit: limit,
                    afterCreatedAt: afterCreatedAt,
                    afterID: afterID
                )
            ).execute().value
            return visits.filter(\.isPublishedOnProfile)
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            let visits = try await sips(
                userID: userID,
                asEveryone: false,
                afterCreatedAt: afterCreatedAt,
                afterID: afterID,
                limit: limit
            )
            return visits.filter(\.isStrictlyPublic)
        }
    }

    func publicCafes(userID: UUID, limit: Int = 500) async throws -> [SharedProfilePublicCafe] {
        try await client.rpc(
            "list_profile_public_cafes_v1",
            params: ProfileCollectionParameters(userID: userID, limit: limit)
        ).execute().value
    }

    func sharedCafes(slug: String, limit: Int = 500) async throws -> [SharedProfilePublicCafe] {
        try await client.rpc(
            "list_profile_share_cafes_v1",
            params: SharedProfileCollectionParameters(slug: slug, limit: limit)
        ).execute().value
    }

    func publicTaggedSips(
        userID: UUID,
        afterCreatedAt: String? = nil,
        afterID: UUID? = nil,
        limit: Int = 24
    ) async throws -> [PublicProfileVisit] {
        let visits: [PublicProfileVisit] = try await client.rpc(
            "list_profile_public_tagged_sips_v1",
            params: PublicProfilePageParameters(
                userID: userID,
                limit: limit,
                afterCreatedAt: afterCreatedAt,
                afterID: afterID
            )
        ).execute().value
        return visits.filter(\.isPublishedOnProfile)
    }

    func sharedTaggedSips(
        slug: String,
        afterCreatedAt: String? = nil,
        afterID: UUID? = nil,
        limit: Int = 24
    ) async throws -> [PublicProfileVisit] {
        let visits: [PublicProfileVisit] = try await client.rpc(
            "list_profile_share_tagged_sips_v1",
            params: SharedProfileSipsParameters(
                slug: slug,
                limit: limit,
                afterCreatedAt: afterCreatedAt,
                afterID: afterID
            )
        ).execute().value
        return visits.filter(\.isPublishedOnProfile)
    }

    func friends(userID: UUID, limit: Int = 100) async throws -> [SharedProfileFriend] {
        try await client.rpc(
            "list_profile_friends_v1",
            params: ProfileCollectionParameters(userID: userID, limit: limit)
        ).execute().value
    }

    func setFavoriteSpots(_ inputs: [ProfileFavoriteSpotInput]) async throws -> [SharedProfileFavoriteSpot] {
        guard let normalized = ProfileFavoriteSpotPolicy.validated(inputs) else {
            throw SharedProfileServiceError.invalidFavoriteSpots
        }
        return try await client.rpc(
            "set_profile_favorite_spots_v1",
            params: FavoriteSpotsParameters(spots: normalized)
        ).execute().value
    }

    func showsFriendsOnPublicProfile() async throws -> Bool {
        do {
            return try await client.rpc("get_profile_friends_visibility_v1")
                .execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            return false
        }
    }

    func setShowsFriendsOnPublicProfile(_ isEnabled: Bool) async throws -> Bool {
        try await client.rpc(
            "set_profile_friends_visibility_v1",
            params: ProfileFriendsVisibilityParameters(isEnabled: isEnabled)
        ).execute().value
    }

    func setTaggedPostHidden(visitID: UUID, hidden: Bool) async throws -> Bool {
        try await client.rpc(
            "set_profile_tagged_post_hidden_v1",
            params: TaggedPostHiddenParameters(visitID: visitID, hidden: hidden)
        ).execute().value
    }

    func sips(
        userID: UUID,
        asEveryone: Bool = false,
        afterCreatedAt: String? = nil,
        afterID: UUID? = nil,
        limit: Int = 24
    ) async throws -> [PublicProfileVisit] {
        try await client.rpc(
            "list_profile_sips_v2",
            params: ProfileSipsParameters(
                userID: userID,
                limit: limit,
                afterCreatedAt: afterCreatedAt,
                afterID: afterID,
                asEveryone: asEveryone
            )
        ).execute().value
    }

    func sharedSips(
        slug: String,
        afterCreatedAt: String? = nil,
        afterID: UUID? = nil,
        limit: Int = 24
    ) async throws -> [PublicProfileVisit] {
        let parameters = SharedProfileSipsParameters(
            slug: slug,
            limit: limit,
            afterCreatedAt: afterCreatedAt,
            afterID: afterID
        )
        do {
            let visits: [PublicProfileVisit] = try await client.rpc(
                "list_profile_share_sips_v2",
                params: parameters
            ).execute().value
            return visits.filter(\.isPublishedOnProfile)
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            let visits: [PublicProfileVisit] = try await client.rpc(
                "list_profile_share_sips_v1",
                params: parameters
            ).execute().value
            return visits.filter(\.isStrictlyPublic)
        }
    }

    func createOwnerShareURL() async throws -> URL? {
        guard let baseURL = configuration.publicBaseURL else { return nil }
        let slug: String = try await client.rpc("create_profile_share_link_v1")
            .execute().value
        return baseURL
            .appendingPathComponent("p", isDirectory: true)
            .appendingPathComponent(slug, isDirectory: false)
    }

    func setHighlight(type: String, targetID: UUID) async throws -> SharedProfileHighlight? {
        try await client.rpc(
            "set_profile_highlight_v1",
            params: SetProfileHighlightParameters(type: type, targetID: targetID)
        ).execute().value
    }

    func clearHighlight() async throws {
        let _: Bool = try await client.rpc("clear_profile_highlight_v1").execute().value
    }
}

enum SharedProfileServiceError: LocalizedError {
    case invalidFavoriteSpots

    var errorDescription: String? {
        "Choose up to three unique cafes and give each one a short descriptor."
    }
}

private struct ProfileProjectionParameters: Encodable {
    let userID: UUID
    let asEveryone: Bool
    enum CodingKeys: String, CodingKey {
        case userID = "p_user_id"
        case asEveryone = "p_as_everyone"
    }
}

private struct ProfileSipsParameters: Encodable {
    let userID: UUID
    let limit: Int
    let afterCreatedAt: String?
    let afterID: UUID?
    let asEveryone: Bool
    enum CodingKeys: String, CodingKey {
        case userID = "p_user_id"
        case limit = "p_limit"
        case afterCreatedAt = "p_after_created_at"
        case afterID = "p_after_id"
        case asEveryone = "p_as_everyone"
    }
}

private struct SharedProfileSipsParameters: Encodable {
    let slug: String
    let limit: Int
    let afterCreatedAt: String?
    let afterID: UUID?
    enum CodingKeys: String, CodingKey {
        case slug = "p_slug"
        case limit = "p_limit"
        case afterCreatedAt = "p_after_created_at"
        case afterID = "p_after_id"
    }
}

private struct PublicProfilePageParameters: Encodable {
    let userID: UUID
    let limit: Int
    let afterCreatedAt: String?
    let afterID: UUID?
    enum CodingKeys: String, CodingKey {
        case userID = "p_user_id"
        case limit = "p_limit"
        case afterCreatedAt = "p_after_created_at"
        case afterID = "p_after_id"
    }
}

private struct ProfileCollectionParameters: Encodable {
    let userID: UUID
    let limit: Int
    enum CodingKeys: String, CodingKey {
        case userID = "p_user_id"
        case limit = "p_limit"
    }
}

private struct SharedProfileCollectionParameters: Encodable {
    let slug: String
    let limit: Int
    enum CodingKeys: String, CodingKey {
        case slug = "p_slug"
        case limit = "p_limit"
    }
}

private struct FavoriteSpotsParameters: Encodable {
    let spots: [ProfileFavoriteSpotInput]
    enum CodingKeys: String, CodingKey { case spots = "p_spots" }
}

private struct ProfileFriendsVisibilityParameters: Encodable {
    let isEnabled: Bool
    enum CodingKeys: String, CodingKey { case isEnabled = "p_enabled" }
}

private struct TaggedPostHiddenParameters: Encodable {
    let visitID: UUID
    let hidden: Bool
    enum CodingKeys: String, CodingKey {
        case visitID = "p_visit_id"
        case hidden = "p_hidden"
    }
}

private struct SetProfileHighlightParameters: Encodable {
    let type: String
    let targetID: UUID
    enum CodingKeys: String, CodingKey {
        case type = "p_highlight_type"
        case targetID = "p_target_id"
    }
}
