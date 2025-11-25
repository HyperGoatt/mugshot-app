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
        // Step 1: Update friend request status to accepted
        let updatePayload = FriendRequestUpdatePayload(status: .accepted)
        let updateBody = try encoder.encode(updatePayload)
        let updateQueryItems = [
            URLQueryItem(name: "id", value: "eq.\(requestId.uuidString)")
        ]
        let (updateData, updateResponse) = try await client.request(
            path: "rest/v1/friend_requests",
            method: "PATCH",
            queryItems: updateQueryItems,
            body: updateBody
        )
        guard (200..<300).contains(updateResponse.statusCode) else {
            throw SupabaseError.server(status: updateResponse.statusCode, message: String(data: updateData, encoding: .utf8))
        }
        
        // Step 2: Create bidirectional friend relationships
        let friendPayloads = [
            FriendInsertPayload(userId: fromUserId, friendUserId: toUserId),
            FriendInsertPayload(userId: toUserId, friendUserId: fromUserId)
        ]
        let friendBody = try encoder.encode(friendPayloads)
        let (friendData, friendResponse) = try await client.request(
            path: "rest/v1/friends",
            method: "POST",
            headers: ["Prefer": "return=minimal"],
            body: friendBody
        )
        guard (200..<300).contains(friendResponse.statusCode) else {
            throw SupabaseError.server(status: friendResponse.statusCode, message: String(data: friendData, encoding: .utf8))
        }
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
    
    // MARK: - Friends
    
    func fetchFriends(for userId: String) async throws -> [String] {
        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "friend_user_id")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/friends",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        let friends = try decoder.decode([RemoteFriend].self, from: data)
        return friends.map { $0.friendUserId }
    }
    
    func removeFriend(userId: String, friendUserId: String) async throws {
        // Remove bidirectional friendship - delete both directions
        let queryItems1 = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "friend_user_id", value: "eq.\(friendUserId)")
        ]
        _ = try await client.request(
            path: "rest/v1/friends",
            method: "DELETE",
            queryItems: queryItems1
        )
        
        let queryItems2 = [
            URLQueryItem(name: "user_id", value: "eq.\(friendUserId)"),
            URLQueryItem(name: "friend_user_id", value: "eq.\(userId)")
        ]
        _ = try await client.request(
            path: "rest/v1/friends",
            method: "DELETE",
            queryItems: queryItems2
        )
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

