//
//  SupabaseNotificationService.swift
//  testMugshot
//

import Foundation

final class SupabaseNotificationService {
    static let shared = SupabaseNotificationService(client: SupabaseClientProvider.shared)
    
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
    
    func fetchNotifications(for userId: String, limit: Int = 50) async throws -> [RemoteNotification] {
        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/notifications",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        return try decoder.decode([RemoteNotification].self, from: data)
    }
    
    func markNotificationRead(id: UUID) async throws {
        let payload = ["read_at": ISO8601DateFormatter().string(from: Date())]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        _ = try await client.request(
            path: "rest/v1/notifications",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Prefer": "return=minimal"],
            body: body
        )
    }
    
    func createNotification(_ payload: NotificationInsertPayload) async throws {
        let body = try encoder.encode([payload])
        let (data, response) = try await client.request(
            path: "rest/v1/notifications",
            method: "POST",
            headers: ["Prefer": "return=minimal"],
            body: body
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
}

struct NotificationInsertPayload: Encodable {
    let userId: String
    let actorUserId: String
    let type: String
    let visitId: UUID?
    let commentId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case actorUserId = "actor_user_id"
        case type
        case visitId = "visit_id"
        case commentId = "comment_id"
    }
}

