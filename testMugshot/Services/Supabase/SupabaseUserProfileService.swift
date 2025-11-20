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
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
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

        if let jsonString = String(data: data, encoding: .utf8) {
            print("[SupabaseUserProfileService] Profile response JSON: \(jsonString)")
        }
        
        let profiles = try jsonDecoder.decode([RemoteUserProfile].self, from: data)
        if let profile = profiles.first {
            print("[SupabaseUserProfileService] Profile decoded successfully - displayName: \(profile.displayName ?? "nil"), username: \(profile.username)")
        } else {
            print("[SupabaseUserProfileService] No profile found in response")
        }
        return profiles.first
    }

    @discardableResult
    func upsertUserProfile(_ profile: RemoteUserProfile) async throws -> RemoteUserProfile {
        let body = try jsonEncoder.encode(profile)

        let (data, response) = try await client.request(
            path: "rest/v1/users",
            method: "POST",
            headers: ["Prefer": "return=representation,resolution=merge-duplicates"],
            body: body
        )

        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }

        let profiles = try jsonDecoder.decode([RemoteUserProfile].self, from: data)
        guard let saved = profiles.first else {
            throw SupabaseError.decoding("Empty response when upserting user profile")
        }
        return saved
    }
    
    /// Update user profile by userId (identity-safe: updates existing user, never creates duplicate)
    @discardableResult
    func updateUserProfile(for userId: String, with profile: RemoteUserProfile.UpdatePayload) async throws -> RemoteUserProfile {
        print("[Identity] Updating profile for userId=\(userId) with new username=\(profile.username ?? "nil"), displayName=\(profile.displayName ?? "nil")")
        
        let body = try jsonEncoder.encode(profile)
        let (data, response) = try await client.request(
            path: "rest/v1/users",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(userId)")
            ],
            headers: [
                "Prefer": "return=representation"
            ],
            body: body
        )

        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Identity] Profile update failed - status: \(response.statusCode), message: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }

        let profiles = try jsonDecoder.decode([RemoteUserProfile].self, from: data)
        guard let saved = profiles.first else {
            throw SupabaseError.decoding("Empty response when updating user profile")
        }
        
        print("[Identity] Profile updated successfully - id=\(saved.id), username=\(saved.username), displayName=\(saved.displayName)")
        return saved
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
}


