//
//  SupabaseUserCafeStateService.swift
//  testMugshot
//
//  Handles syncing user's favorite and want_to_try cafe states with Supabase.
//

import Foundation

/// Remote model for user_cafe_states table
struct RemoteUserCafeState: Codable {
    let id: UUID?
    let userId: String
    let cafeId: UUID
    let isFavorite: Bool
    let wantToTry: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cafeId = "cafe_id"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Payload for upserting user cafe states
struct UserCafeStateUpsertPayload: Encodable {
    let userId: String
    let cafeId: UUID
    let isFavorite: Bool
    let wantToTry: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case cafeId = "cafe_id"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
    }
}

final class SupabaseUserCafeStateService {
    static let shared = SupabaseUserCafeStateService(client: SupabaseClientProvider.shared)
    
    private let client: SupabaseClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(client: SupabaseClient) {
        self.client = client
        self.decoder = SupabaseDateDecoder.shared
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    /// Fetch all cafe states for a user (favorites and want_to_try)
    /// Returns all cafes where user has set either flag to true
    func fetchUserCafeStates(userId: String) async throws -> [RemoteUserCafeState] {
        print("[UserCafeState] Fetching cafe states for userId: \(userId.prefix(8))...")
        
        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*"),
            // Only fetch states where at least one flag is true (for efficiency)
            URLQueryItem(name: "or", value: "(is_favorite.eq.true,want_to_try.eq.true)")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/user_cafe_states",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[UserCafeState] Failed to fetch states: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        
        let states = try decoder.decode([RemoteUserCafeState].self, from: data)
        print("[UserCafeState] Fetched \(states.count) cafe states")
        
        // Log breakdown
        let favorites = states.filter { $0.isFavorite }.count
        let wantToTry = states.filter { $0.wantToTry }.count
        print("[UserCafeState] Breakdown - favorites: \(favorites), want_to_try: \(wantToTry)")
        
        return states
    }
    
    /// Upsert a cafe state (create or update)
    /// Uses Supabase upsert with on_conflict to handle existing records
    func upsertCafeState(
        userId: String,
        cafeId: UUID,
        isFavorite: Bool,
        wantToTry: Bool
    ) async throws {
        print("[UserCafeState] Upserting state for cafeId: \(cafeId) - favorite: \(isFavorite), wantToTry: \(wantToTry)")
        
        let payload = UserCafeStateUpsertPayload(
            userId: userId,
            cafeId: cafeId,
            isFavorite: isFavorite,
            wantToTry: wantToTry
        )
        
        let body = try encoder.encode([payload])
        
        // Use upsert with conflict resolution on (user_id, cafe_id)
        let (data, response) = try await client.request(
            path: "rest/v1/user_cafe_states",
            method: "POST",
            headers: [
                "Prefer": "resolution=merge-duplicates",
                "Content-Type": "application/json"
            ],
            body: body
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[UserCafeState] Failed to upsert state: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        
        print("[UserCafeState] Successfully upserted state for cafeId: \(cafeId)")
    }
    
    /// Delete a cafe state (when both flags are false)
    /// Optional cleanup - not strictly necessary since we filter by flags when fetching
    func deleteCafeState(userId: String, cafeId: UUID) async throws {
        print("[UserCafeState] Deleting state for cafeId: \(cafeId)")
        
        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "cafe_id", value: "eq.\(cafeId)")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/user_cafe_states",
            method: "DELETE",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[UserCafeState] Failed to delete state: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        
        print("[UserCafeState] Successfully deleted state for cafeId: \(cafeId)")
    }
}

