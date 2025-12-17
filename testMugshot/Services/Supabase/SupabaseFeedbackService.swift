//
//  SupabaseFeedbackService.swift
//  testMugshot
//
//  Service layer for feedback board CRUD operations
//

import Foundation

final class SupabaseFeedbackService {
    static let shared = SupabaseFeedbackService(client: SupabaseClientProvider.shared)
    
    private let client: SupabaseClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(client: SupabaseClient) {
        self.client = client
        self.decoder = SupabaseDateDecoder.shared
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Fetch Posts
    
    /// Fetches feedback posts with vote counts and comment counts
    func fetchFeedbackPosts(
        category: FeedbackCategory? = nil,
        sortBy: FeedbackSortOption = .new,
        limit: Int = 50
    ) async throws -> [FeedbackPost] {
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        // Filter by category if specified
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: "eq.\(category.rawValue)"))
        }
        
        // Sort order
        switch sortBy {
        case .new:
            queryItems.append(URLQueryItem(name: "order", value: "created_at.desc"))
        case .top:
            queryItems.append(URLQueryItem(name: "order", value: "vote_score.desc,created_at.desc"))
        case .hot:
            // Hot = recent posts with high engagement
            queryItems.append(URLQueryItem(name: "order", value: "vote_score.desc,comment_count.desc,created_at.desc"))
        }
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_posts_with_counts",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        return try decoder.decode([FeedbackPost].self, from: data)
    }
    
    /// Fetches a single feedback post by ID
    func fetchFeedbackPost(id: UUID) async throws -> FeedbackPost? {
        let queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_posts_with_counts",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        let posts = try decoder.decode([FeedbackPost].self, from: data)
        return posts.first
    }
    
    // MARK: - Create Post
    
    /// Creates a new feedback post
    func createFeedbackPost(
        userId: String,
        title: String,
        body: String,
        category: FeedbackCategory
    ) async throws -> FeedbackPost {
        let payload = FeedbackPostInsertPayload(
            userId: userId,
            title: title,
            body: body,
            category: category.rawValue
        )
        
        let bodyData = try encoder.encode([payload])
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_posts",
            method: "POST",
            headers: ["Prefer": "return=representation"],
            body: bodyData
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        // The returned post won't have the view fields, so fetch it again
        let insertedPosts = try decoder.decode([InsertedFeedbackPost].self, from: data)
        guard let insertedPost = insertedPosts.first else {
            throw SupabaseError.decoding("No post returned after insert")
        }
        
        // Fetch the full post with counts
        guard let fullPost = try await fetchFeedbackPost(id: insertedPost.id) else {
            throw SupabaseError.decoding("Could not fetch created post")
        }
        
        return fullPost
    }
    
    // MARK: - Delete Post
    
    /// Deletes a feedback post (only owner can delete via RLS)
    func deleteFeedbackPost(id: UUID) async throws {
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_posts",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Prefer": "return=minimal"]
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
    
    // MARK: - Voting
    
    /// Gets the current user's vote for a post
    func getUserVote(userId: String, postId: UUID) async throws -> FeedbackVoteType? {
        let queryItems = [
            URLQueryItem(name: "select", value: "vote_type"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "post_id", value: "eq.\(postId.uuidString)")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_votes",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        struct VoteResult: Decodable {
            let voteType: Int
            enum CodingKeys: String, CodingKey {
                case voteType = "vote_type"
            }
        }
        
        let votes = try decoder.decode([VoteResult].self, from: data)
        guard let vote = votes.first else { return nil }
        return FeedbackVoteType(rawValue: vote.voteType)
    }
    
    /// Gets multiple votes for the current user (batch)
    func getUserVotes(userId: String, postIds: [UUID]) async throws -> [UUID: FeedbackVoteType] {
        guard !postIds.isEmpty else { return [:] }
        
        let idsString = postIds.map { $0.uuidString }.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "select", value: "post_id,vote_type"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "post_id", value: "in.(\(idsString))")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_votes",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        struct VoteResult: Decodable {
            let postId: UUID
            let voteType: Int
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case voteType = "vote_type"
            }
        }
        
        let votes = try decoder.decode([VoteResult].self, from: data)
        var result: [UUID: FeedbackVoteType] = [:]
        for vote in votes {
            if let voteType = FeedbackVoteType(rawValue: vote.voteType) {
                result[vote.postId] = voteType
            }
        }
        return result
    }
    
    /// Votes on a feedback post (upsert - creates or updates)
    func voteFeedbackPost(userId: String, postId: UUID, voteType: FeedbackVoteType) async throws {
        let payload = FeedbackVoteUpsertPayload(
            userId: userId,
            postId: postId.uuidString,
            voteType: voteType.rawValue
        )
        
        let bodyData = try encoder.encode([payload])
        
        // Use upsert with on_conflict to handle existing votes
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_votes",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,post_id")],
            headers: [
                "Prefer": "resolution=merge-duplicates,return=minimal"
            ],
            body: bodyData
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
    
    /// Removes the current user's vote from a post
    func removeVote(userId: String, postId: UUID) async throws {
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_votes",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "post_id", value: "eq.\(postId.uuidString)")
            ],
            headers: ["Prefer": "return=minimal"]
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
    
    // MARK: - Comments
    
    /// Fetches comments for a post with author info
    func fetchComments(postId: UUID) async throws -> [FeedbackComment] {
        let queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "post_id", value: "eq.\(postId.uuidString)"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_comments_with_author",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        return try decoder.decode([FeedbackComment].self, from: data)
    }
    
    /// Adds a comment to a post
    func addComment(
        userId: String,
        postId: UUID,
        text: String,
        parentCommentId: UUID? = nil
    ) async throws -> FeedbackComment {
        let payload = FeedbackCommentInsertPayload(
            userId: userId,
            postId: postId.uuidString,
            parentCommentId: parentCommentId?.uuidString,
            text: text
        )
        
        let bodyData = try encoder.encode([payload])
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_comments",
            method: "POST",
            headers: ["Prefer": "return=representation"],
            body: bodyData
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        // Fetch the comment with author info
        struct InsertedComment: Decodable {
            let id: UUID
        }
        
        let insertedComments = try decoder.decode([InsertedComment].self, from: data)
        guard let insertedComment = insertedComments.first else {
            throw SupabaseError.decoding("No comment returned after insert")
        }
        
        // Fetch the full comment with author info
        let fullComment = try await fetchComment(id: insertedComment.id)
        guard let comment = fullComment else {
            throw SupabaseError.decoding("Could not fetch created comment")
        }
        
        return comment
    }
    
    /// Fetches a single comment by ID
    private func fetchComment(id: UUID) async throws -> FeedbackComment? {
        let queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_comments_with_author",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        let comments = try decoder.decode([FeedbackComment].self, from: data)
        return comments.first
    }
    
    /// Deletes a comment (only owner can delete via RLS)
    func deleteComment(id: UUID) async throws {
        let (data, response) = try await client.request(
            path: "rest/v1/feedback_comments",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Prefer": "return=minimal"]
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
}

// MARK: - Helper Types

private struct InsertedFeedbackPost: Decodable {
    let id: UUID
}



