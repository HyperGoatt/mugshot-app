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
        case .system:
            return "bell.fill"
        }
    }
}

struct MugshotNotification: Identifiable, Codable {
    let id: UUID
    let type: NotificationType
    var actorUsername: String?
    var actorDisplayName: String?
    var actorAvatarKey: String? // PhotoCache key for profile image
    var targetVisitId: UUID? // ID of the related visit/post if applicable
    var targetCafeName: String? // For human-readable context
    var message: String // Human readable notification text
    var createdAt: Date
    var isRead: Bool
    
    init(
        id: UUID = UUID(),
        type: NotificationType,
        actorUsername: String? = nil,
        actorDisplayName: String? = nil,
        actorAvatarKey: String? = nil,
        targetVisitId: UUID? = nil,
        targetCafeName: String? = nil,
        message: String,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.actorUsername = actorUsername
        self.actorDisplayName = actorDisplayName
        self.actorAvatarKey = actorAvatarKey
        self.targetVisitId = targetVisitId
        self.targetCafeName = targetCafeName
        self.message = message
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

