//
//  PushNotificationPayload.swift
//  testMugshot
//
//  Model for parsing push notification payloads from APNs
//

import Foundation
import UserNotifications

/// Standard payload format for Mugshot push notifications
/// Mirrors the in-app MugshotNotification model structure
struct PushNotificationPayload {
    let type: NotificationType
    let actorUsername: String?
    let actorAvatarURL: String?
    let visitId: UUID?
    let friendUserId: String?
    let cafeName: String?
    let tapAction: TapAction
    
    enum TapAction: String {
        case visitDetail = "visit_detail"
        case friendProfile = "friend_profile"
        case friendsFeed = "friends_feed"
        case notifications = "notifications"
    }
    
    /// Parse from UNNotificationRequest (APNs payload)
    init?(from notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        // Extract type
        guard let typeString = userInfo["type"] as? String,
              let notificationType = NotificationType(rawValue: typeString) else {
            print("⚠️ [Push] Missing or invalid notification type")
            return nil
        }
        self.type = notificationType
        
        // Extract actor info
        self.actorUsername = userInfo["actor_username"] as? String
        self.actorAvatarURL = userInfo["actor_avatar_url"] as? String
        
        // Extract visit ID if present
        if let visitIdString = userInfo["visit_id"] as? String,
           let visitId = UUID(uuidString: visitIdString) {
            self.visitId = visitId
        } else {
            self.visitId = nil
        }
        
        // Extract friend user ID if present
        self.friendUserId = userInfo["friend_user_id"] as? String
        
        // Extract cafe name if present
        self.cafeName = userInfo["cafe_name"] as? String
        
        // Extract tap action (default to friends feed if missing)
        if let tapActionString = userInfo["tap_action"] as? String,
           let action = TapAction(rawValue: tapActionString) {
            self.tapAction = action
        } else {
            // Infer tap action from type if not explicitly provided
            switch notificationType {
            case .like, .comment, .newVisitFromFriend:
                self.tapAction = visitId != nil ? .visitDetail : .friendsFeed
            case .friendRequest, .friendAccept, .friendJoin:
                self.tapAction = friendUserId != nil ? .friendProfile : .notifications
            default:
                self.tapAction = .friendsFeed
            }
        }
    }
    
    /// Parse from userInfo dictionary (for background/launch scenarios)
    init?(from userInfo: [AnyHashable: Any]) {
        // Parse directly from userInfo dictionary (same logic as UNNotification initializer)
        let info = userInfo as? [String: Any] ?? [:]
        
        // Extract type
        guard let typeString = info["type"] as? String,
              let notificationType = NotificationType(rawValue: typeString) else {
            print("⚠️ [Push] Missing or invalid notification type")
            return nil
        }
        self.type = notificationType
        
        // Extract actor info
        self.actorUsername = info["actor_username"] as? String
        self.actorAvatarURL = info["actor_avatar_url"] as? String
        
        // Extract visit ID if present
        if let visitIdString = info["visit_id"] as? String,
           let visitId = UUID(uuidString: visitIdString) {
            self.visitId = visitId
        } else {
            self.visitId = nil
        }
        
        // Extract friend user ID if present
        self.friendUserId = info["friend_user_id"] as? String
        
        // Extract cafe name if present
        self.cafeName = info["cafe_name"] as? String
        
        // Extract tap action (default to friends feed if missing)
        if let tapActionString = info["tap_action"] as? String,
           let action = TapAction(rawValue: tapActionString) {
            self.tapAction = action
        } else {
            // Infer tap action from type if not explicitly provided
            switch notificationType {
            case .like, .comment, .newVisitFromFriend:
                self.tapAction = visitId != nil ? .visitDetail : .friendsFeed
            case .friendRequest, .friendAccept, .friendJoin:
                self.tapAction = friendUserId != nil ? .friendProfile : .notifications
            default:
                self.tapAction = .friendsFeed
            }
        }
    }
}

