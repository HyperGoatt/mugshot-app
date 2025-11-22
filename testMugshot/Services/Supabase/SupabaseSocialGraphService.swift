//
//  SupabaseSocialGraphService.swift
//  testMugshot
//

import Foundation

final class SupabaseSocialGraphService {
    static let shared = SupabaseSocialGraphService(client: SupabaseClientProvider.shared)
    
    private let client: SupabaseClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(client: SupabaseClient) {
        self.client = client
        // Use shared decoder that handles Postgres timestamps and ISO8601 variants
        self.decoder = SupabaseDateDecoder.shared
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    func fetchFollowingIds(for userId: String) async throws -> [String] {
        let queryItems = [
            URLQueryItem(name: "follower_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "followee_id")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/follows",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        let follows = try decoder.decode([RemoteFollow].self, from: data)
        return follows.map { $0.followeeId }
    }
    
    func follow(userId: String, targetUserId: String) async throws {
        let payload = FollowMutationPayload(followerId: userId, followeeId: targetUserId)
        let body = try encoder.encode([payload])
        let (data, response) = try await client.request(
            path: "rest/v1/follows",
            method: "POST",
            headers: ["Prefer": "return=minimal"],
            body: body
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
    
    func unfollow(userId: String, targetUserId: String) async throws {
        _ = try await client.request(
            path: "rest/v1/follows",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "follower_id", value: "eq.\(userId)"),
                URLQueryItem(name: "followee_id", value: "eq.\(targetUserId)")
            ]
        )
    }
}

private struct FollowMutationPayload: Encodable {
    let followerId: String
    let followeeId: String
    
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followeeId = "followee_id"
    }
}

