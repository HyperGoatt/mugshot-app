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
    
    func fetchFollowerIds(for userId: String) async throws -> [String] {
        let queryItems = [
            URLQueryItem(name: "followee_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "follower_id")
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
        return follows.map { $0.followerId }
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
    
    // MARK: - Friend Requests
    
    func sendFriendRequest(from userId: String, to targetUserId: String) async throws -> RemoteFriendRequest {
        let payload = FriendRequestInsertPayload(fromUserId: userId, toUserId: targetUserId, status: .pending)
        let body = try encoder.encode([payload])
        let (data, response) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "POST",
            headers: ["Prefer": "return=representation"],
            body: body
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        let requests = try decoder.decode([RemoteFriendRequest].self, from: data)
        guard let request = requests.first else {
            throw SupabaseError.decoding("Friend request insert returned empty response.")
        }
        return request
    }
    
    func fetchIncomingFriendRequests(for userId: String) async throws -> [RemoteFriendRequest] {
        let queryItems = [
            URLQueryItem(name: "to_user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "status", value: "eq.pending"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        return try decoder.decode([RemoteFriendRequest].self, from: data)
    }
    
    func fetchOutgoingFriendRequests(for userId: String) async throws -> [RemoteFriendRequest] {
        let queryItems = [
            URLQueryItem(name: "from_user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "status", value: "eq.pending"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        return try decoder.decode([RemoteFriendRequest].self, from: data)
    }
    
    func acceptFriendRequest(requestId: UUID, fromUserId: String, toUserId: String) async throws {
        // Step 1: Mark any previous "accepted" requests between these users as "rejected"
        // RLS policies allow the recipient (to_user_id) to update the row but not delete it.
        // Updating them to "rejected" avoids violating the UNIQUE (from_user_id, to_user_id, status) constraint.
        let cleanupPayload = FriendRequestUpdatePayload(status: .rejected)
        let cleanupBody = try encoder.encode(cleanupPayload)
        let cleanupQueryItems = [
            URLQueryItem(name: "from_user_id", value: "eq.\(fromUserId)"),
            URLQueryItem(name: "to_user_id", value: "eq.\(toUserId)"),
            URLQueryItem(name: "status", value: "eq.accepted")
        ]
        let (cleanupData, cleanupResponse) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "PATCH",
            queryItems: cleanupQueryItems,
            body: cleanupBody
        )
        
        if (200..<300).contains(cleanupResponse.statusCode) {
            print("[SupabaseSocialGraphService] acceptFriendRequest: Cleared previous accepted requests (status -> rejected)")
        } else {
            let errorMessage = String(data: cleanupData, encoding: .utf8) ?? ""
            print("[SupabaseSocialGraphService] acceptFriendRequest: Warning - failed to clean previous accepted requests: \(errorMessage)")
            // Continue anyway; worst case we'll hit the constraint and surface the real error.
        }
        
        // Step 2: Update the pending request to accepted
        let updatePayload = FriendRequestUpdatePayload(status: .accepted)
        let updateBody = try encoder.encode(updatePayload)
        let updateQueryItems = [
            URLQueryItem(name: "id", value: "eq.\(requestId.uuidString)"),
            URLQueryItem(name: "status", value: "eq.pending") // Only update if status is pending
        ]
        let (updateData, updateResponse) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "PATCH",
            queryItems: updateQueryItems,
            body: updateBody
        )
        
        if !(200..<300).contains(updateResponse.statusCode) {
            let errorMessage = String(data: updateData, encoding: .utf8) ?? ""
            
            // If update fails with constraint violation, check if request was already accepted
            if errorMessage.contains("23505") || errorMessage.contains("duplicate key") {
                print("[SupabaseSocialGraphService] acceptFriendRequest: Constraint violation - checking if request was already accepted")
                
                // Fetch the request to check its current status
                let fetchQueryItems = [
                    URLQueryItem(name: "id", value: "eq.\(requestId.uuidString)")
                ]
                let (fetchData, fetchResponse) = try await client.request(
                    path: "rest/v1/friend_requests",
                    method: "GET",
                    queryItems: fetchQueryItems
                )
                
                if (200..<300).contains(fetchResponse.statusCode),
                   let requests = try? decoder.decode([RemoteFriendRequest].self, from: fetchData),
                   let request = requests.first,
                   request.status == .accepted {
                    // Request is already accepted, proceed to ensure friends exist
                    print("[SupabaseSocialGraphService] acceptFriendRequest: Request already accepted, proceeding to ensure friends exist")
                    // Continue to Step 3 (create friends)
                } else {
                    // Constraint violation but request isn't accepted - this shouldn't happen after cleanup
                    throw SupabaseError.server(status: updateResponse.statusCode, message: "Failed to accept friend request: \(errorMessage)")
                }
            } else {
                throw SupabaseError.server(status: updateResponse.statusCode, message: errorMessage)
            }
        }
        
        // Step 3: Create bidirectional friend relationships
        // CRITICAL: Insert each direction separately to ensure both succeed
        // This prevents partial failures where only one direction gets created
        
        print("[SupabaseSocialGraphService] Creating friendship: \(fromUserId.prefix(8)) ↔ \(toUserId.prefix(8))")
        
        // Direction 1: fromUserId -> toUserId
        let payload1 = [FriendInsertPayload(userId: fromUserId, friendUserId: toUserId)]
        let body1 = try encoder.encode(payload1)
        let (data1, response1) = try await client.request(
            path: "rest/v1/friends",
            method: "POST",
            headers: ["Prefer": "return=minimal"],
            body: body1
        )
        
        if !(200..<300).contains(response1.statusCode) {
            let errorMessage = String(data: data1, encoding: .utf8) ?? ""
            // Only ignore duplicate key errors - everything else should fail
            if errorMessage.contains("23505") || errorMessage.contains("duplicate key") {
                print("[SupabaseSocialGraphService] ✅ Direction 1 already exists: \(fromUserId.prefix(8)) -> \(toUserId.prefix(8))")
            } else {
                print("[SupabaseSocialGraphService] ❌ Failed to create direction 1: \(errorMessage)")
                throw SupabaseError.server(status: response1.statusCode, message: "Failed to create friendship direction 1: \(errorMessage)")
            }
        } else {
            print("[SupabaseSocialGraphService] ✅ Created direction 1: \(fromUserId.prefix(8)) -> \(toUserId.prefix(8))")
        }
        
        // Direction 2: toUserId -> fromUserId
        let payload2 = [FriendInsertPayload(userId: toUserId, friendUserId: fromUserId)]
        let body2 = try encoder.encode(payload2)
        let (data2, response2) = try await client.request(
            path: "rest/v1/friends",
            method: "POST",
            headers: ["Prefer": "return=minimal"],
            body: body2
        )
        
        if !(200..<300).contains(response2.statusCode) {
            let errorMessage = String(data: data2, encoding: .utf8) ?? ""
            // Only ignore duplicate key errors - everything else should fail
            if errorMessage.contains("23505") || errorMessage.contains("duplicate key") {
                print("[SupabaseSocialGraphService] ✅ Direction 2 already exists: \(toUserId.prefix(8)) -> \(fromUserId.prefix(8))")
            } else {
                print("[SupabaseSocialGraphService] ❌ Failed to create direction 2: \(errorMessage)")
                throw SupabaseError.server(status: response2.statusCode, message: "Failed to create friendship direction 2: \(errorMessage)")
            }
        } else {
            print("[SupabaseSocialGraphService] ✅ Created direction 2: \(toUserId.prefix(8)) -> \(fromUserId.prefix(8))")
        }
        
        print("[SupabaseSocialGraphService] 🎉 Bidirectional friendship complete!")
    }
    
    func rejectFriendRequest(requestId: UUID) async throws {
        let updatePayload = FriendRequestUpdatePayload(status: .rejected)
        let updateBody = try encoder.encode(updatePayload)
        let queryItems = [
            URLQueryItem(name: "id", value: "eq.\(requestId.uuidString)")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "PATCH",
            queryItems: queryItems,
            body: updateBody
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
    
    func cancelFriendRequest(requestId: UUID) async throws {
        let queryItems = [
            URLQueryItem(name: "id", value: "eq.\(requestId.uuidString)")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "DELETE",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
    
    // MARK: - Friends
    
    func fetchFriends(for userId: String) async throws -> [String] {
        // Primary source of truth: explicit friendships table
        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "user_id,friend_user_id")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/friends",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseSocialGraphService] ❌ fetchFriends failed for \(userId.prefix(8)): \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        let friends = try decoder.decode([RemoteFriend].self, from: data)
        let directFriendIds = friends.map { $0.friendUserId }
        
        print("[SupabaseSocialGraphService] ✅ Fetched \(directFriendIds.count) friends for \(userId.prefix(8))")
        
        if !directFriendIds.isEmpty {
            return directFriendIds
        }
        
        // Fallback: treat mutual follows as friends if explicit friendships
        // haven't been created yet (e.g., legacy data or pre-friends system).
        print("[SupabaseSocialGraphService] ⚠️ No explicit friends found, checking mutual follows fallback...")
        let followingIds = try await fetchFollowingIds(for: userId)
        let followerIds = try await fetchFollowerIds(for: userId)
        
        let mutuals = Set(followingIds).intersection(Set(followerIds))
        print("[SupabaseSocialGraphService] ℹ️ Found \(mutuals.count) mutual follows for \(userId.prefix(8))")
        return Array(mutuals)
    }
    
    func removeFriend(userId: String, friendUserId: String) async throws {
        print("[SupabaseSocialGraphService] 👋 Removing friendship: \(userId.prefix(8)) ↔ \(friendUserId.prefix(8))")
        
        // Remove bidirectional friendship - delete both directions
        // Direction 1: userId -> friendUserId
        let queryItems1 = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "friend_user_id", value: "eq.\(friendUserId)")
        ]
        let (data1, response1) = try await client.request(
            path: "rest/v1/friends",
            method: "DELETE",
            queryItems: queryItems1
        )
        
        if !(200..<300).contains(response1.statusCode) {
            let errorMsg = String(data: data1, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseSocialGraphService] ❌ Failed to remove direction 1: \(errorMsg)")
            throw SupabaseError.server(status: response1.statusCode, message: errorMsg)
        }
        print("[SupabaseSocialGraphService] ✅ Removed direction 1: \(userId.prefix(8)) -> \(friendUserId.prefix(8))")
        
        // Direction 2: friendUserId -> userId
        let queryItems2 = [
            URLQueryItem(name: "user_id", value: "eq.\(friendUserId)"),
            URLQueryItem(name: "friend_user_id", value: "eq.\(userId)")
        ]
        let (data2, response2) = try await client.request(
            path: "rest/v1/friends",
            method: "DELETE",
            queryItems: queryItems2
        )
        
        if !(200..<300).contains(response2.statusCode) {
            let errorMsg = String(data: data2, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseSocialGraphService] ❌ Failed to remove direction 2: \(errorMsg)")
            throw SupabaseError.server(status: response2.statusCode, message: errorMsg)
        }
        print("[SupabaseSocialGraphService] ✅ Removed direction 2: \(friendUserId.prefix(8)) -> \(userId.prefix(8))")
        print("[SupabaseSocialGraphService] 💔 Friendship completely removed")
    }
    
    func checkFriendshipStatus(currentUserId: String, otherUserId: String) async throws -> FriendshipStatus {
        // Check if they're already friends
        let friendsQueryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(currentUserId)"),
            URLQueryItem(name: "friend_user_id", value: "eq.\(otherUserId)")
        ]
        let (friendsData, friendsResponse) = try await client.request(
            path: "rest/v1/friends",
            method: "GET",
            queryItems: friendsQueryItems
        )
        
        if (200..<300).contains(friendsResponse.statusCode) {
            let friends = try decoder.decode([RemoteFriend].self, from: friendsData)
            if !friends.isEmpty {
                return .friends
            }
        }
        
        // Check for incoming request (other user sent to current user)
        let incomingQueryItems = [
            URLQueryItem(name: "from_user_id", value: "eq.\(otherUserId)"),
            URLQueryItem(name: "to_user_id", value: "eq.\(currentUserId)"),
            URLQueryItem(name: "status", value: "eq.pending")
        ]
        let (incomingData, incomingResponse) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "GET",
            queryItems: incomingQueryItems
        )
        
        if (200..<300).contains(incomingResponse.statusCode) {
            let requests = try decoder.decode([RemoteFriendRequest].self, from: incomingData)
            if let request = requests.first {
                return .incomingRequest(request.id)
            }
        }
        
        // Check for outgoing request (current user sent to other user)
        let outgoingQueryItems = [
            URLQueryItem(name: "from_user_id", value: "eq.\(currentUserId)"),
            URLQueryItem(name: "to_user_id", value: "eq.\(otherUserId)"),
            URLQueryItem(name: "status", value: "eq.pending")
        ]
        let (outgoingData, outgoingResponse) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "GET",
            queryItems: outgoingQueryItems
        )
        
        if (200..<300).contains(outgoingResponse.statusCode) {
            let requests = try decoder.decode([RemoteFriendRequest].self, from: outgoingData)
            if let request = requests.first {
                return .outgoingRequest(request.id)
            }
        }
        
        return .none
    }
}

// MARK: - Payloads

private struct FollowMutationPayload: Encodable {
    let followerId: String
    let followeeId: String
    
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followeeId = "followee_id"
    }
}

private struct FriendRequestInsertPayload: Encodable {
    let fromUserId: String
    let toUserId: String
    let status: FriendRequestStatus
    
    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case status
    }
}

private struct FriendRequestUpdatePayload: Encodable {
    let status: FriendRequestStatus
    
    enum CodingKeys: String, CodingKey {
        case status
    }
}

private struct FriendInsertPayload: Encodable {
    let userId: String
    let friendUserId: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case friendUserId = "friend_user_id"
    }
}

