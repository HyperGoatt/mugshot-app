//
//  MugshotNotification.swift
//  testMugshot
//
//  Notification model for social interactions
//

import Foundation

enum NotificationType: String, Codable {
    case newVisitFromFriend = "new_visit_from_friend"
    case like = "like"
    case comment = "comment"
    case reply = "reply"
    case mention = "mention"
    case follow = "follow"
    case friendRequest = "friend_request"
    case friendAccept = "friend_accept"
    case friendJoin = "friend_join"
    case system = "system"
    
    var displayIcon: String {
        switch self {
        case .newVisitFromFriend:
            return "person.crop.circle.badge.plus"
        case .like:
            return "heart.fill"
        case .comment:
            return "bubble.left.fill"
        case .reply:
            return "arrowshape.turn.up.left.fill"
        case .mention:
            return "at"
        case .follow:
            return "person.crop.circle.badge.plus"
        case .friendRequest:
            return "person.crop.circle.badge.plus"
        case .friendAccept:
            return "person.crop.circle.badge.checkmark"
        case .friendJoin:
            return "person.crop.circle.badge.plus"
        case .system:
            return "bell.fill"
        }
    }
}

struct MugshotNotification: Identifiable, Codable {
    let id: UUID
    var supabaseId: UUID?
    let type: NotificationType
    var supabaseUserId: String?
    var actorSupabaseUserId: String?
    var actorUsername: String?
    var actorDisplayName: String?
    var actorAvatarKey: String? // PhotoCache key for profile image
    var targetVisitId: UUID? // ID of the related visit/post if applicable
    var visitSupabaseId: UUID?
    var targetCafeName: String? // For human-readable context
    var commentSupabaseId: UUID?
    var message: String // Human readable notification text
    var createdAt: Date
    var isRead: Bool
    
    init(
        id: UUID = UUID(),
        supabaseId: UUID? = nil,
        type: NotificationType,
        supabaseUserId: String? = nil,
        actorSupabaseUserId: String? = nil,
        actorUsername: String? = nil,
        actorDisplayName: String? = nil,
        actorAvatarKey: String? = nil,
        targetVisitId: UUID? = nil,
        visitSupabaseId: UUID? = nil,
        targetCafeName: String? = nil,
        commentSupabaseId: UUID? = nil,
        message: String,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.type = type
        self.supabaseUserId = supabaseUserId
        self.actorSupabaseUserId = actorSupabaseUserId
        self.actorUsername = actorUsername
        self.actorDisplayName = actorDisplayName
        self.actorAvatarKey = actorAvatarKey
        self.targetVisitId = targetVisitId
        self.visitSupabaseId = visitSupabaseId
        self.targetCafeName = targetCafeName
        self.commentSupabaseId = commentSupabaseId
        self.message = message
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

