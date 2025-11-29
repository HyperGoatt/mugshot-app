//
//  SupabaseVisitService.swift
//  testMugshot
//

import Foundation

final class SupabaseVisitService {
    static let shared = SupabaseVisitService(client: SupabaseClientProvider.shared)
    
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
    
    // MARK: - Fetch feeds
    
    func fetchEveryoneFeed(limit: Int = 50) async throws -> [RemoteVisit] {
        var queryItems = baseSelectQuery(limit: limit)
        queryItems.append(URLQueryItem(name: "visibility", value: "eq.everyone"))
        return try await fetchVisits(queryItems: queryItems)
    }
    
    func fetchFriendsFeed(currentUserId: String, followingIds: [String], limit: Int = 50) async throws -> [RemoteVisit] {
        var userIds = Set(followingIds)
        userIds.insert(currentUserId)
        let list = userIds.joined(separator: ",")
        var queryItems = baseSelectQuery(limit: limit)
        queryItems.append(URLQueryItem(name: "user_id", value: "in.(\(list))"))
        queryItems.append(URLQueryItem(name: "visibility", value: "in.(friends,everyone)"))
        return try await fetchVisits(queryItems: queryItems)
    }
    
    func fetchVisitsForUserProfile(userId: String, limit: Int = 50) async throws -> [RemoteVisit] {
        var queryItems = baseSelectQuery(limit: limit)
        queryItems.append(URLQueryItem(name: "user_id", value: "eq.\(userId)"))
        return try await fetchVisits(queryItems: queryItems)
    }
    
    func fetchVisitById(_ id: UUID) async throws -> RemoteVisit? {
        var queryItems = baseSelectQuery(limit: 1)
        queryItems.append(URLQueryItem(name: "id", value: "eq.\(id.uuidString)"))
        let visits = try await fetchVisits(queryItems: queryItems)
        return visits.first
    }
    
    // MARK: - Mutations
    
    /// Creates a visit in Supabase
    /// Inserts into public.visits table, then inserts photos into public.visit_photos
    /// RLS policy requires: auth.uid() = user_id (enforced by Supabase)
    func createVisit(
        payload: VisitInsertPayload,
        photos: [VisitPhotoUpload]
    ) async throws -> RemoteVisit {
        print("[VisitService] ===== Creating Visit in Supabase =====")
        print("[VisitService] userId = \(payload.userId)")
        print("[VisitService] cafeId = \(payload.cafeId)")
        print("[VisitService] visibility = \(payload.visibility)")
        print("[VisitService] overallScore = \(payload.overallScore)")
        print("[VisitService] photoCount = \(photos.count)")
        
        let body = try encoder.encode([payload])
        
        // Log the request body (excluding binary data)
        if let bodyString = String(data: body, encoding: .utf8) {
            print("[VisitService] Request body: \(bodyString)")
        }
        
        print("[VisitService] Sending POST to rest/v1/visits")
        let (data, response) = try await client.request(
            path: "rest/v1/visits",
            method: "POST",
            headers: ["Prefer": "return=representation"],
            body: body
        )
        
        print("[VisitService] Response status: \(response.statusCode)")
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [VisitService] ===== VISIT INSERT FAILED =====")
            print("❌ [VisitService] Status: \(response.statusCode)")
            print("❌ [VisitService] Error message: \(errorMessage)")
            
            // Try to parse error details if available
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("❌ [VisitService] Error JSON: \(errorJSON)")
                if let message = errorJSON["message"] as? String {
                    print("❌ [VisitService] Parsed message: \(message)")
                }
                if let hint = errorJSON["hint"] as? String {
                    print("❌ [VisitService] Hint: \(hint)")
                }
                if let details = errorJSON["details"] as? String {
                    print("❌ [VisitService] Details: \(details)")
                }
                if let code = errorJSON["code"] as? String {
                    print("❌ [VisitService] Error code: \(code)")
                }
            }
            
            // Log the request payload for debugging
            if let bodyString = String(data: body, encoding: .utf8) {
                print("❌ [VisitService] Request payload that failed: \(bodyString)")
            }
            
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }
        
        // Debug: Log raw JSON response before decoding (for debugging date format issues)
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("✅ [VisitService] Visit insert response JSON (raw): \(jsonString)")
        }
        #endif
        
        do {
            let visits = try decoder.decode([RemoteVisit].self, from: data)
            guard let savedVisit = visits.first else {
                print("❌ [VisitService] Visit insert returned empty response array")
                throw SupabaseError.decoding("Visit insert returned empty response.")
            }
            
            print("✅ [VisitService] Visit created successfully - id: \(savedVisit.id)")
        
            // Insert photos if any
            if !photos.isEmpty {
                let payloads = photos.enumerated().map { index, upload in
                    VisitPhotoInsertPayload(
                        visitId: savedVisit.id,
                        photoURL: upload.photoURL,
                        sortOrder: upload.sortOrder ?? index
                    )
                }
                try await insertVisitPhotos(payloads)
            }
        
            // Try to fetch the full visit with relations, but fallback to savedVisit if fetch fails
            // This handles cases where the fetch might fail due to timing or decoding issues
            do {
                if let fetchedVisit = try await fetchVisitById(savedVisit.id) {
                    print("✅ Successfully fetched visit with relations")
                    return fetchedVisit
                } else {
                    print("⚠️ fetchVisitById returned nil, using savedVisit from insert")
                    return savedVisit
                }
            } catch {
                // If fetching fails (e.g., decoding error with relations), use the visit from insert
                // This ensures we don't fail the entire operation if the fetch has issues
                print("⚠️ Failed to fetch visit with relations: \(error.localizedDescription)")
                print("⚠️ Using savedVisit from insert response instead")
                return savedVisit
            }
        } catch let decodingError as DecodingError {
            print("❌ [VisitService] Failed to decode visit insert response: \(decodingError)")
            
            // Log detailed decoding error information
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("❌ [VisitService] Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("❌ [VisitService] Context: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("❌ [VisitService] Value not found: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("❌ [VisitService] Context: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("❌ [VisitService] Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("❌ [VisitService] Context: \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("❌ [VisitService] Data corrupted: \(context.debugDescription)")
                print("❌ [VisitService] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                if let underlyingError = context.underlyingError {
                    print("❌ [VisitService] Underlying error: \(underlyingError)")
                }
            @unknown default:
                print("❌ [VisitService] Unknown decoding error")
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ [VisitService] Raw JSON that failed to decode: \(jsonString)")
            }
            throw SupabaseError.decoding("Failed to decode visit response: \(decodingError.localizedDescription)")
        } catch {
            print("❌ [VisitService] Unexpected error decoding visit: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ [VisitService] Raw JSON: \(jsonString)")
            }
            throw error
        }
    }
    
    func addLike(visitId: UUID, userId: String) async throws -> RemoteLike {
        let payload = LikeInsertPayload(visitId: visitId, userId: userId)
        let body = try encoder.encode([payload])
        let (data, response) = try await client.request(
            path: "rest/v1/likes",
            method: "POST",
            headers: ["Prefer": "return=representation"],
            body: body
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        let likes = try decoder.decode([RemoteLike].self, from: data)
        guard let saved = likes.first else {
            throw SupabaseError.decoding("Like insert returned empty response.")
        }
        return saved
    }
    
    func removeLike(visitId: UUID, userId: String) async throws {
        _ = try await client.request(
            path: "rest/v1/likes",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "visit_id", value: "eq.\(visitId.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userId)")
            ]
        )
    }
    
    func addComment(visitId: UUID, userId: String, text: String) async throws -> RemoteComment {
        let payload = CommentInsertPayload(visitId: visitId, userId: userId, text: text)
        let body = try encoder.encode([payload])
        let (data, response) = try await client.request(
            path: "rest/v1/comments",
            method: "POST",
            headers: ["Prefer": "return=representation"],
            body: body
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        let comments = try decoder.decode([RemoteComment].self, from: data)
        guard let saved = comments.first else {
            throw SupabaseError.decoding("Comment insert returned empty response.")
        }
        return saved
    }
    
    func deleteComment(commentId: UUID) async throws {
        _ = try await client.request(
            path: "rest/v1/comments",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(commentId.uuidString)")
            ]
        )
    }
    
    /// Update the notes field of a visit. Used when the author edits their notes in the Journal.
    func updateVisitNotes(visitId: UUID, notes: String?) async throws {
        let payload: [String: Any?] = ["notes": notes]
        let body = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 }, options: [])
        
        let (data, response) = try await client.request(
            path: "rest/v1/visits",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(visitId.uuidString)")
            ],
            headers: ["Prefer": "return=minimal"],
            body: body
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [VisitService] Failed to update visit notes: \(errorMessage)")
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }
        
        print("✅ [VisitService] Visit notes updated successfully for visitId: \(visitId)")
    }
    
    /// Update multiple fields of a visit. Used when the author edits their visit.
    func updateVisit(
        visitId: UUID,
        drinkType: String,
        customDrinkType: String?,
        caption: String,
        notes: String?,
        visibility: String,
        ratings: [String: Double],
        overallScore: Double
    ) async throws {
        var payload: [String: Any] = [
            "drink_type": drinkType,
            "caption": caption,
            "visibility": visibility,
            "ratings": ratings,
            "overall_score": overallScore
        ]
        
        // Add optional fields
        if let customDrinkType = customDrinkType {
            payload["custom_drink_type"] = customDrinkType
        } else {
            payload["custom_drink_type"] = NSNull()
        }
        
        if let notes = notes {
            payload["notes"] = notes
        } else {
            payload["notes"] = NSNull()
        }
        
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let (data, response) = try await client.request(
            path: "rest/v1/visits",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(visitId.uuidString)")
            ],
            headers: ["Prefer": "return=minimal"],
            body: body
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [VisitService] Failed to update visit: \(errorMessage)")
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }
        
        print("✅ [VisitService] Visit updated successfully for visitId: \(visitId)")
    }
    
    /// Update the text of a comment. Used when the author edits their own comment.
    func updateComment(commentId: UUID, newText: String) async throws -> RemoteComment {
        let payload = ["text": newText]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let (data, response) = try await client.request(
            path: "rest/v1/comments",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(commentId.uuidString)"),
                URLQueryItem(name: "select", value: "*")
            ],
            headers: ["Prefer": "return=representation"],
            body: body
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        let comments = try decoder.decode([RemoteComment].self, from: data)
        guard let updated = comments.first else {
            throw SupabaseError.decoding("Comment update returned empty response.")
        }
        return updated
    }
    
    func fetchComments(visitId: UUID) async throws -> [RemoteComment] {
        let queryItems = [
            URLQueryItem(name: "visit_id", value: "eq.\(visitId.uuidString)"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/comments",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        return try decoder.decode([RemoteComment].self, from: data)
    }
    
    // MARK: - Helpers
    
    private func baseSelectQuery(limit: Int) -> [URLQueryItem] {
        let selectValue = "*,cafe:cafe_id(*),visit_photos(*),likes(*),comments(*),author:users!visits_user_id_fkey(id,display_name,username,avatar_url)"
        return [
            URLQueryItem(name: "select", value: selectValue),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
    }
    
    private func fetchVisits(queryItems: [URLQueryItem]) async throws -> [RemoteVisit] {
        let (data, response) = try await client.request(
            path: "rest/v1/visits",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        return try decoder.decode([RemoteVisit].self, from: data)
    }
    
    private func insertVisitPhotos(_ payloads: [VisitPhotoInsertPayload]) async throws {
        guard !payloads.isEmpty else { return }
        let body = try encoder.encode(payloads)
        let (data, response) = try await client.request(
            path: "rest/v1/visit_photos",
            method: "POST",
            headers: ["Prefer": "return=minimal"],
            body: body
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
}

// MARK: - Payloads

struct VisitInsertPayload: Encodable {
    let userId: String
    let cafeId: UUID
    var drinkType: String?
    var drinkTypeCustom: String?
    let caption: String
    let notes: String?
    let visibility: String
    let ratings: [String: Double]
    let overallScore: Double
    let posterPhotoURL: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case cafeId = "cafe_id"
        case drinkType = "drink_type"
        case drinkTypeCustom = "drink_type_custom"
        case caption
        case notes
        case visibility
        case ratings
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
    }
}

struct VisitPhotoUpload {
    let photoURL: String
    let sortOrder: Int?
}

private struct VisitPhotoInsertPayload: Encodable {
    let visitId: UUID
    let photoURL: String
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case photoURL = "photo_url"
        case sortOrder = "sort_order"
    }
}

private struct LikeInsertPayload: Encodable {
    let visitId: UUID
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case userId = "user_id"
    }
}

private struct CommentInsertPayload: Encodable {
    let visitId: UUID
    let userId: String
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case userId = "user_id"
        case text
    }
}

