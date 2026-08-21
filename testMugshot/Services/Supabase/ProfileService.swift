//
//  ProfileService.swift
//  testMugshot
//

import Foundation
import Supabase

final class ProfileService {
    private let client: SupabaseClient

    private let profileColumns = """
    id, display_name, username, bio, location, favorite_drink, instagram_handle, avatar_url, banner_url, website_url
    """

    init(client: SupabaseClient) {
        self.client = client
    }

    func bootstrapProfile(
        for authUser: AuthenticatedUser,
        localUser: User?
    ) async throws -> SupabaseUserProfile {
        if let profile = try await fetchProfile(userId: authUser.id) {
            return profile
        }

        let fallback = SupabaseUserProfileUpsert(
            id: authUser.id,
            displayName: fallbackDisplayName(for: authUser, localUser: localUser),
            username: fallbackUsername(for: authUser, localUser: localUser),
            bio: localUser?.bio.nilIfEmpty,
            location: localUser?.location.nilIfEmpty
        )

        return try await client
            .from("users")
            .upsert(fallback, onConflict: "id")
            .select(profileColumns)
            .single()
            .execute()
            .value
    }

    func fetchProfile(userId: UUID) async throws -> SupabaseUserProfile? {
        let profiles: [SupabaseUserProfile] = try await client
            .from("users")
            .select(profileColumns)
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        return profiles.first
    }

    func fetchProfiles(ids: some Collection<UUID>) async throws -> [SupabaseUserProfile] {
        let identifiers = Array(Set(ids))
        guard !identifiers.isEmpty else { return [] }

        return try await client
            .from("users")
            .select(profileColumns)
            .in("id", values: identifiers.map(\.uuidString))
            .execute()
            .value
    }

    func updateProfile(
        userId: UUID,
        update: SupabaseUserProfileUpdate
    ) async throws -> SupabaseUserProfile {
        try await client
            .from("users")
            .update(update)
            .eq("id", value: userId.uuidString)
            .select(profileColumns)
            .single()
            .execute()
            .value
    }

    func updateAvatar(
        userId: UUID,
        avatarURL: String
    ) async throws -> SupabaseUserProfile {
        try await client
            .from("users")
            .update(ProfileAvatarUpdate(avatarURL: avatarURL))
            .eq("id", value: userId.uuidString)
            .select(profileColumns)
            .single()
            .execute()
            .value
    }

    func updateBanner(
        userId: UUID,
        bannerURL: String
    ) async throws -> SupabaseUserProfile {
        try await client
            .from("users")
            .update(ProfileBannerUpdate(bannerURL: bannerURL))
            .eq("id", value: userId.uuidString)
            .select(profileColumns)
            .single()
            .execute()
            .value
    }

    private func fallbackDisplayName(for authUser: AuthenticatedUser, localUser: User?) -> String {
        if let displayName = localUser?.displayName?.nilIfEmpty {
            return displayName
        }

        if let username = localUser?.username.nilIfEmpty {
            return username
        }

        if let preferredDisplayName = authUser.preferredDisplayName?.nilIfEmpty {
            return preferredDisplayName
        }

        return authUser.email?.split(separator: "@").first.map(String.init) ?? "Mugshot User"
    }

    private func fallbackUsername(for authUser: AuthenticatedUser, localUser: User?) -> String {
        if let username = localUser?.username.nilIfEmpty {
            let sanitized = sanitizeUsername(username)
            if sanitized.count >= 3 {
                return sanitized
            }
        }

        let emailPrefix = authUser.email?.split(separator: "@").first.map(String.init) ?? "user"
        let base = sanitizeUsername(emailPrefix)
        let safeBase = base.count >= 3 ? base : "user"
        return "\(safeBase)_\(authUser.id.uuidString.prefix(4).lowercased())"
    }

    private func sanitizeUsername(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

struct ProfileSetupState: Decodable, Equatable {
    let userID: UUID
    let isComplete: Bool
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case isComplete = "is_complete"
        case completedAt = "completed_at"
    }
}

final class ProfileSetupService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func state() async throws -> ProfileSetupState {
        try await client.rpc("get_profile_setup_state_v1").execute().value
    }

    func complete(
        displayName: String,
        username: String,
        bio: String,
        location: String,
        instagramHandle: String,
        websiteURL: String,
        favoriteDrink: String
    ) async throws -> SupabaseUserProfile {
        try await client.rpc(
            "complete_profile_setup_v1",
            params: CompleteProfileSetupParameters(
                displayName: displayName,
                username: username,
                bio: bio,
                location: location,
                instagramHandle: instagramHandle,
                websiteURL: websiteURL,
                favoriteDrink: favoriteDrink
            )
        ).execute().value
    }
}

private struct CompleteProfileSetupParameters: Encodable {
    let displayName: String
    let username: String
    let bio: String
    let location: String
    let instagramHandle: String
    let websiteURL: String
    let favoriteDrink: String

    enum CodingKeys: String, CodingKey {
        case displayName = "p_display_name"
        case username = "p_username"
        case bio = "p_bio"
        case location = "p_location"
        case instagramHandle = "p_instagram_handle"
        case websiteURL = "p_website_url"
        case favoriteDrink = "p_favorite_drink"
    }
}

private struct ProfileAvatarUpdate: Encodable {
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
    }
}

private struct ProfileBannerUpdate: Encodable {
    let bannerURL: String

    enum CodingKeys: String, CodingKey {
        case bannerURL = "banner_url"
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
