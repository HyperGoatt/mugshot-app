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
    
    private func fallbackDisplayName(for authUser: AuthenticatedUser, localUser: User?) -> String {
        if let displayName = localUser?.displayName?.nilIfEmpty {
            return displayName
        }
        
        if let username = localUser?.username.nilIfEmpty {
            return username
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

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

