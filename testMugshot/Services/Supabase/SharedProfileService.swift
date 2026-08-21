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
        try await client.rpc(
            "get_profile_projection_v2",
            params: ProfileProjectionParameters(userID: userID, asEveryone: asEveryone)
        ).execute().value
    }

    func sharedProjection(slug: String) async throws -> SharedProfileProjection? {
        guard MugshotSharedLinkRoute.isValidSlug(slug) else { return nil }
        return try await client.rpc(
            "get_profile_share_v1",
            params: ["p_slug": slug]
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
        try await client.rpc(
            "list_profile_share_sips_v1",
            params: SharedProfileSipsParameters(
                slug: slug,
                limit: limit,
                afterCreatedAt: afterCreatedAt,
                afterID: afterID
            )
        ).execute().value
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

private struct SetProfileHighlightParameters: Encodable {
    let type: String
    let targetID: UUID
    enum CodingKeys: String, CodingKey {
        case type = "p_highlight_type"
        case targetID = "p_target_id"
    }
}
