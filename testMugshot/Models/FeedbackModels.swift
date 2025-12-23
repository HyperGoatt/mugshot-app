//
//  FeedbackModels.swift
//  testMugshot
//
//  Models for the feedback board feature
//

import Foundation

// MARK: - Feedback Category

enum FeedbackCategory: String, CaseIterable, Codable {
    case bug = "bug"
    case feature = "feature"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .bug: return "Bug"
        case .feature: return "Feature"
        case .general: return "General"
        }
    }
    
    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .feature: return "lightbulb"
        case .general: return "bubble.left"
        }
    }
}

// MARK: - Vote Type

enum FeedbackVoteType: Int, Codable {
    case up = 1
    case down = -1
}

// MARK: - Sort Options

enum FeedbackSortOption: String, CaseIterable {
    case top = "Top"
    case new = "New"
    case hot = "Hot"
}

// MARK: - Feedback Post

struct FeedbackPost: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: String
    let title: String
    let body: String
    let category: FeedbackCategory
    let createdAt: Date
    let updatedAt: Date
    
    // Joined fields from view
    let authorUsername: String?
    let authorDisplayName: String?
    let authorAvatarUrl: String?
    let voteScore: Int
    let upvotes: Int
    let downvotes: Int
    let commentCount: Int
    
    // Local state for current user's vote
    var currentUserVote: FeedbackVoteType?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case body
        case category
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorUsername = "author_username"
        case authorDisplayName = "author_display_name"
        case authorAvatarUrl = "author_avatar_url"
        case voteScore = "vote_score"
        case upvotes
        case downvotes
        case commentCount = "comment_count"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        category = try container.decode(FeedbackCategory.self, forKey: .category)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername)
        authorDisplayName = try container.decodeIfPresent(String.self, forKey: .authorDisplayName)
        authorAvatarUrl = try container.decodeIfPresent(String.self, forKey: .authorAvatarUrl)
        voteScore = try container.decodeIfPresent(Int.self, forKey: .voteScore) ?? 0
        upvotes = try container.decodeIfPresent(Int.self, forKey: .upvotes) ?? 0
        downvotes = try container.decodeIfPresent(Int.self, forKey: .downvotes) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        currentUserVote = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(category, forKey: .category)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    var authorName: String {
        authorDisplayName ?? authorUsername ?? "Anonymous"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    static func == (lhs: FeedbackPost, rhs: FeedbackPost) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Feedback Vote

struct FeedbackVote: Identifiable, Codable {
    let id: UUID
    let userId: String
    let postId: UUID
    let voteType: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case voteType = "vote_type"
        case createdAt = "created_at"
    }
    
    var voteTypeEnum: FeedbackVoteType? {
        FeedbackVoteType(rawValue: voteType)
    }
}

// MARK: - Feedback Comment

struct FeedbackComment: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: String
    let postId: UUID
    let parentCommentId: UUID?
    let text: String
    let createdAt: Date
    
    // Joined fields from view
    let authorUsername: String?
    let authorDisplayName: String?
    let authorAvatarUrl: String?
    
    // For nested display
    var replies: [FeedbackComment]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case parentCommentId = "parent_comment_id"
        case text
        case createdAt = "created_at"
        case authorUsername = "author_username"
        case authorDisplayName = "author_display_name"
        case authorAvatarUrl = "author_avatar_url"
    }
    
    var authorName: String {
        authorDisplayName ?? authorUsername ?? "Anonymous"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    static func == (lhs: FeedbackComment, rhs: FeedbackComment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Insert Payloads

struct FeedbackPostInsertPayload: Encodable {
    let userId: String
    let title: String
    let body: String
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case body
        case category
    }
}

struct FeedbackVoteUpsertPayload: Encodable {
    let userId: String
    let postId: String
    let voteType: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
        case voteType = "vote_type"
    }
}

struct FeedbackCommentInsertPayload: Encodable {
    let userId: String
    let postId: String
    let parentCommentId: String?
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
        case parentCommentId = "parent_comment_id"
        case text
    }
}





