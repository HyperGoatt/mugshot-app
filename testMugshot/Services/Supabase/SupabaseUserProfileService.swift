//
//  SupabaseUserProfileService.swift
//  testMugshot
//

import Foundation

final class SupabaseUserProfileService {
    static let shared = SupabaseUserProfileService(client: SupabaseClientProvider.shared)

    private let client: SupabaseClient
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(client: SupabaseClient) {
        self.client = client
        // Use shared decoder that handles Postgres timestamps and ISO8601 variants
        self.jsonDecoder = SupabaseDateDecoder.shared
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    func fetchUserProfile(userId: String) async throws -> RemoteUserProfile? {
        print("[SupabaseUserProfileService] fetchUserProfile called for userId: \(userId)")
        let (data, response) = try await client.request(
            path: "rest/v1/users",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(userId)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "limit", value: "1")
            ],
            headers: ["Prefer": "return=representation"],
            body: nil
        )

        print("[SupabaseUserProfileService] Profile fetch response status: \(response.statusCode)")
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseUserProfileService] Profile fetch failed - status: \(response.statusCode), message: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }

        // Log raw JSON response before decoding (for debugging date format issues)
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[SupabaseUserProfileService] Profile response JSON (raw): \(jsonString)")
        }
        #endif
        
        do {
            let profiles = try jsonDecoder.decode([RemoteUserProfile].self, from: data)
            if let profile = profiles.first {
                print("[SupabaseUserProfileService] Profile decoded successfully - displayName: \(profile.displayName), username: \(profile.username)")
            } else {
                print("[SupabaseUserProfileService] No profile found in response")
            }
            return profiles.first
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("❌ [SupabaseUserProfileService] Decode error while parsing user profile response")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ [SupabaseUserProfileService] Raw JSON that failed to decode: \(jsonString)")
            }
            switch decodingError {
            case .dataCorrupted(let context):
                print("❌ [SupabaseUserProfileService] Data corrupted: \(context.debugDescription)")
                print("❌ [SupabaseUserProfileService] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            default:
                print("❌ [SupabaseUserProfileService] Decoding error: \(decodingError)")
            }
            #endif
            throw SupabaseError.decoding("Failed to decode user profile: \(decodingError.localizedDescription)")
        }
    }

    @discardableResult
    func upsertUserProfile(_ profile: RemoteUserProfile) async throws -> RemoteUserProfile {
        print("[SupabaseUserProfileService] upsertUserProfile: Starting upsert for userId=\(profile.id), username=\(profile.username), displayName=\(profile.displayName)")
        let body = try jsonEncoder.encode(profile)
        
        if let jsonString = String(data: body, encoding: .utf8) {
            print("[SupabaseUserProfileService] upsertUserProfile: Request body: \(jsonString)")
        }

        let (data, response) = try await client.request(
            path: "rest/v1/users",
            method: "POST",
            headers: ["Prefer": "return=representation,resolution=merge-duplicates"],
            body: body
        )

        print("[SupabaseUserProfileService] upsertUserProfile: Response status=\(response.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[SupabaseUserProfileService] upsertUserProfile: Response body: \(responseString)")
        }

        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseUserProfileService] upsertUserProfile: Failed - status: \(response.statusCode), message: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }

        // Handle empty response
        if data.isEmpty || String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
            print("[SupabaseUserProfileService] upsertUserProfile: Empty response - fetching profile to verify")
            // Try to fetch the profile to see if it was created
            if let fetchedProfile = try await fetchUserProfile(userId: profile.id) {
                print("[SupabaseUserProfileService] upsertUserProfile: Profile exists after upsert - id=\(fetchedProfile.id), username=\(fetchedProfile.username)")
                return fetchedProfile
            } else {
                print("[SupabaseUserProfileService] upsertUserProfile: Profile does not exist after upsert - this may indicate an RLS or constraint issue")
                throw SupabaseError.decoding("Empty response when upserting user profile and profile does not exist")
            }
        }
        
        // Try to decode the response
        do {
            let profiles = try jsonDecoder.decode([RemoteUserProfile].self, from: data)
            guard let saved = profiles.first else {
                print("[SupabaseUserProfileService] upsertUserProfile: Empty response array after decode")
                // Try fetching as fallback
                if let fetchedProfile = try? await fetchUserProfile(userId: profile.id) {
                    print("[SupabaseUserProfileService] upsertUserProfile: Profile exists (fetched as fallback) - id=\(fetchedProfile.id), username=\(fetchedProfile.username)")
                    return fetchedProfile
                }
                throw SupabaseError.decoding("Empty response when upserting user profile")
            }
            print("[SupabaseUserProfileService] upsertUserProfile: Success - saved profile id=\(saved.id), username=\(saved.username)")
            return saved
        } catch let decodingError as DecodingError {
            print("[SupabaseUserProfileService] upsertUserProfile: Decoding error - \(decodingError)")
            // Log detailed decoding error
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("[SupabaseUserProfileService] Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .valueNotFound(let type, let context):
                print("[SupabaseUserProfileService] Value not found: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .keyNotFound(let key, let context):
                print("[SupabaseUserProfileService] Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                print("[SupabaseUserProfileService] Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("[SupabaseUserProfileService] Unknown decoding error")
            }
            
            // Try fetching as fallback
            if let fetchedProfile = try? await fetchUserProfile(userId: profile.id) {
                print("[SupabaseUserProfileService] upsertUserProfile: Profile exists (fetched after decode error) - id=\(fetchedProfile.id), username=\(fetchedProfile.username)")
                return fetchedProfile
            }
            
            throw SupabaseError.decoding("Failed to decode profile response: \(decodingError.localizedDescription)")
        } catch {
            print("[SupabaseUserProfileService] upsertUserProfile: Unexpected error - \(error)")
            // Try fetching as fallback
            if let fetchedProfile = try? await fetchUserProfile(userId: profile.id) {
                print("[SupabaseUserProfileService] upsertUserProfile: Profile exists (fetched after error) - id=\(fetchedProfile.id), username=\(fetchedProfile.username)")
                return fetchedProfile
            }
            throw error
        }
    }
    
    /// Update user profile by userId (identity-safe: updates existing user, never creates duplicate)
    @discardableResult
    func updateUserProfile(for userId: String, with profile: RemoteUserProfile.UpdatePayload) async throws -> RemoteUserProfile {
        print("[Identity] Updating profile for userId=\(userId) with new username=\(profile.username ?? "nil"), displayName=\(profile.displayName ?? "nil")")
        
        // Encode the payload
        let body = try jsonEncoder.encode(profile)
        if let bodyString = String(data: body, encoding: .utf8) {
            print("[Identity] PATCH /rest/v1/users request body: \(bodyString)")
        }
        
        // Make the PATCH request with explicit select and return=representation
        let (data, response) = try await client.request(
            path: "rest/v1/users",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(userId)"),
                URLQueryItem(name: "select", value: "id,display_name,username,bio,location,favorite_drink,instagram_handle,website_url,avatar_url,banner_url,created_at,updated_at")
            ],
            headers: [
                "Prefer": "return=representation"
            ],
            body: body
        )

        print("[Identity] PATCH /rest/v1/users response status: \(response.statusCode)")
        let responseBodyString = String(data: data, encoding: .utf8) ?? "<empty or non-UTF8>"
        print("[Identity] PATCH /rest/v1/users response body: \(responseBodyString)")

        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = responseBodyString
            print("[Identity] Profile update failed - status: \(response.statusCode), message: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }

        // Handle empty response gracefully
        if data.isEmpty || responseBodyString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
            print("[Identity] PATCH returned empty response (status \(response.statusCode)) - checking if profile exists")
            // Fetch the profile to see if it exists
            if let existingProfile = try await fetchUserProfile(userId: userId) {
                // Profile exists but PATCH returned empty - this shouldn't happen, but try fetching again
                print("[Identity] Profile exists but PATCH returned empty - returning existing profile")
                return existingProfile
            } else {
                // Profile doesn't exist - create it instead of updating
                print("[Identity] Profile does not exist - creating new profile from update payload")
                
                // Ensure required fields are present for creation
                guard let displayName = profile.displayName, !displayName.isEmpty,
                      let username = profile.username, !username.isEmpty else {
                    throw SupabaseError.decoding("Cannot create profile: display_name and username are required")
                }
                
                // Create a full RemoteUserProfile from the UpdatePayload
                let newProfile = RemoteUserProfile(
                    id: userId,
                    displayName: displayName,
                    username: username.lowercased(), // Ensure lowercase for consistency
                    bio: profile.bio,
                    location: profile.location,
                    favoriteDrink: profile.favoriteDrink,
                    instagramHandle: profile.instagramHandle,
                    websiteURL: profile.websiteURL,
                    avatarURL: profile.avatarURL,
                    bannerURL: profile.bannerURL,
                    createdAt: nil,
                    updatedAt: nil
                )
                
                // Use upsert to create the profile
                let createdProfile = try await upsertUserProfile(newProfile)
                print("[Identity] Profile created successfully - id=\(createdProfile.id), username=\(createdProfile.username), displayName=\(createdProfile.displayName)")
                return createdProfile
            }
        }

        // Try to decode the response
        do {
            let profiles = try jsonDecoder.decode([RemoteUserProfile].self, from: data)
            if let saved = profiles.first {
                print("[Identity] Profile updated successfully - id=\(saved.id), username=\(saved.username), displayName=\(saved.displayName)")
                return saved
            } else {
                print("[Identity] Decoded empty array - fetching updated profile")
                // Empty array but successful status - fetch the updated profile
                if let updatedProfile = try await fetchUserProfile(userId: userId) {
                    print("[Identity] Profile updated successfully (fetched after empty array) - id=\(updatedProfile.id), username=\(updatedProfile.username), displayName=\(updatedProfile.displayName)")
                    return updatedProfile
                } else {
                    throw SupabaseError.decoding("Empty response array when updating user profile and could not fetch updated profile")
                }
            }
        } catch {
            print("[Identity] Failed to decode response: \(error.localizedDescription)")
            // If decoding fails but status is 2xx, try fetching the updated profile
            if let updatedProfile = try? await fetchUserProfile(userId: userId) {
                print("[Identity] Profile updated successfully (fetched after decode failure) - id=\(updatedProfile.id), username=\(updatedProfile.username), displayName=\(updatedProfile.displayName)")
                return updatedProfile
            } else {
                // Re-throw the original decoding error
                throw SupabaseError.decoding("Failed to decode Supabase response: \(error.localizedDescription)")
            }
        }
    }

    func fetchRatingTemplate(userId: String) async throws -> RemoteRatingTemplate? {
        let (data, response) = try await client.request(
            path: "rest/v1/rating_templates",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "limit", value: "1")
            ],
            headers: ["Prefer": "return=representation"],
            body: nil
        )

        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }

        let templates = try jsonDecoder.decode([RemoteRatingTemplate].self, from: data)
        return templates.first
    }

    @discardableResult
    func upsertRatingTemplate(_ template: RemoteRatingTemplate) async throws -> RemoteRatingTemplate {
        let body = try jsonEncoder.encode(template)

        let (data, response) = try await client.request(
            path: "rest/v1/rating_templates",
            method: "POST",
            headers: ["Prefer": "return=representation,resolution=merge-duplicates"],
            body: body
        )

        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }

        let templates = try jsonDecoder.decode([RemoteRatingTemplate].self, from: data)
        guard let saved = templates.first else {
            throw SupabaseError.decoding("Empty response when upserting rating_templates")
        }
        return saved
    }
    
    // MARK: - User Search
    
    /// Search for users by username or display name using case-insensitive partial matching
    func searchUsers(query: String, excludingUserId: String, limit: Int = 20) async throws -> [RemoteUserProfile] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            print("[FriendsSearch] Empty query, returning empty results")
            return []
        }
        
        print("[FriendsSearch] search triggered with query='\(trimmedQuery)'")
        print("[FriendsSearch] Searching users, excluding userId=\(excludingUserId)")
        
        // PostgREST ilike filter: search username OR display_name
        // Format: or=(username.ilike.*query*,display_name.ilike.*query*)
        // The * in PostgREST represents % in SQL ILIKE
        let orFilter = "username.ilike.*\(trimmedQuery)*,display_name.ilike.*\(trimmedQuery)*"
        
        let queryItems = [
            URLQueryItem(name: "or", value: "(\(orFilter))"),
            URLQueryItem(name: "id", value: "neq.\(excludingUserId)"),
            URLQueryItem(name: "select", value: "id,username,display_name,avatar_url,bio,location,favorite_drink,instagram_handle,website_url,banner_url,created_at,updated_at"),
            URLQueryItem(name: "order", value: "username.asc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        // Log the constructed query
        let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        print("[FriendsSearch] Request query: /rest/v1/users?\(queryString)")
        
        let (data, response) = try await client.request(
            path: "rest/v1/users",
            method: "GET",
            queryItems: queryItems,
            headers: ["Prefer": "return=representation"],
            body: nil
        )
        
        print("[FriendsSearch] Response status: \(response.statusCode)")
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[FriendsSearch] Search failed - status: \(response.statusCode), message: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        
        // Log raw response for debugging
        if let rawBody = String(data: data, encoding: .utf8) {
            print("[FriendsSearch] Raw response body: \(rawBody)")
        }
        
        do {
            let profiles = try jsonDecoder.decode([RemoteUserProfile].self, from: data)
            print("[FriendsSearch] Raw Supabase users count: \(profiles.count)")
            for profile in profiles {
                print("[FriendsSearch] Remote user: id=\(profile.id), username=\(profile.username), displayName=\(profile.displayName)")
            }
            print("[FriendsSearch] Query='\(trimmedQuery)', results=\(profiles.count)")
            return profiles
        } catch {
            print("[FriendsSearch] Decoding error: \(error)")
            throw SupabaseError.decoding("Failed to decode user profiles: \(error.localizedDescription)")
        }
    }
}


