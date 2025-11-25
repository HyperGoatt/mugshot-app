//
//  SupabaseUserDeviceService.swift
//  testMugshot
//
//  Service for managing user device push tokens in Supabase
//

import Foundation

final class SupabaseUserDeviceService {
    static let shared = SupabaseUserDeviceService(client: SupabaseClientProvider.shared)
    
    private let client: SupabaseClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(client: SupabaseClient) {
        self.client = client
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = SupabaseDateDecoder.shared
    }
    
    /// Upserts a device token for a user (creates if doesn't exist, updates if it does)
    /// Uses Supabase's upsert with conflict resolution on (user_id, push_token)
    func upsertDeviceToken(userId: String, token: String, platform: String = "ios") async throws {
        print("[Push] Upserting device token for userId=\(userId.prefix(8))..., platform=\(platform)")
        
        let payload = UserDevicePayload(
            userId: userId,
            pushToken: token,
            platform: platform
        )
        
        let body = try encoder.encode(payload)
        
        // Use Supabase upsert: POST with Prefer: resolution=merge-duplicates
        // The unique constraint on (user_id, push_token) will handle conflicts
        let (data, response) = try await client.request(
            path: "rest/v1/user_devices",
            method: "POST",
            headers: [
                "Prefer": "resolution=merge-duplicates",
                "Content-Type": "application/json"
            ],
            body: body
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [Push] Failed to upsert device token - status: \(response.statusCode), message: \(errorMessage)")
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }
        
        print("✅ [Push] Device token upserted successfully")
    }
    
    /// Fetches all device tokens for a user (useful for debugging)
    func fetchUserDevices(userId: String) async throws -> [RemoteUserDevice] {
        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/user_devices",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        return try decoder.decode([RemoteUserDevice].self, from: data)
    }
    
    /// Deletes a device token (e.g., when user logs out or uninstalls)
    func deleteDeviceToken(userId: String, token: String) async throws {
        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "push_token", value: "eq.\(token)")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/user_devices",
            method: "DELETE",
            queryItems: queryItems,
            headers: ["Prefer": "return=minimal"]
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        print("[Push] Device token deleted successfully")
    }
}

// MARK: - Payload Models

struct UserDevicePayload: Encodable {
    let userId: String
    let pushToken: String
    let platform: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case pushToken = "push_token"
        case platform
    }
}

struct RemoteUserDevice: Codable {
    let id: UUID
    let userId: String
    let pushToken: String
    let platform: String
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pushToken = "push_token"
        case platform
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        
        // Handle userId: Supabase returns UUID as string
        if let userIdUUID = try? container.decode(UUID.self, forKey: .userId) {
            userId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .userId) {
            userId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.userId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "user_id is required"))
        }
        
        pushToken = try container.decode(String.self, forKey: .pushToken)
        platform = try container.decode(String.self, forKey: .platform)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

