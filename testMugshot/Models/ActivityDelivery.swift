import Foundation

enum MugshotActivityKind: String, Codable, CaseIterable {
    case friendPost = "friend_post"
    case tag
    case collaborativeListInvitation = "collaborative_list_invitation"
    case collaborativeListInvitationAccepted = "collaborative_list_invitation_accepted"
    case collaborativeListInvitationDeclined = "collaborative_list_invitation_declined"
    case collaborativeListInvitationCancelled = "collaborative_list_invitation_cancelled"
    case collaborativeListRoleChanged = "collaborative_list_role_changed"
    case collaborativeListMemberRemoved = "collaborative_list_member_removed"
    case collaborativeListMemberLeft = "collaborative_list_member_left"
    case collaborativeListOwnershipTransferred = "collaborative_list_ownership_transferred"
    case collaborativeListDeleted = "collaborative_list_deleted"
    case like
    case comment
    case commentMention = "comment_mention"
    case reaction
    case friendRequest = "friend_request"
    case friendRequestAccepted = "friend_request_accepted"

    var systemImage: String {
        switch self {
        case .friendPost: "cup.and.saucer.fill"
        case .tag, .commentMention: "at"
        case .collaborativeListInvitation,
             .collaborativeListInvitationAccepted,
             .collaborativeListInvitationDeclined,
             .collaborativeListInvitationCancelled,
             .collaborativeListRoleChanged,
             .collaborativeListMemberRemoved,
             .collaborativeListMemberLeft,
             .collaborativeListOwnershipTransferred,
             .collaborativeListDeleted:
            "rectangle.stack.badge.person.crop.fill"
        case .like: "heart.fill"
        case .comment: "bubble.left.fill"
        case .reaction: "sparkles"
        case .friendRequest: "person.crop.circle.badge.plus"
        case .friendRequestAccepted: "person.2.fill"
        }
    }
}

struct MugshotActivityEvent: Decodable, Identifiable, Equatable {
    let id: UUID
    let kind: MugshotActivityKind
    let actorUserID: UUID
    let actorDisplayName: String?
    let actorUsername: String
    let actorAvatarURL: String?
    let title: String
    let body: String
    let visitID: UUID?
    let commentID: UUID?
    let cafeListID: UUID?
    let friendRequestID: UUID?
    let deepLink: String
    let canOpenVisit: Bool
    let canRemoveTag: Bool
    let createdAt: String
    var readAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "event_id"
        case kind
        case actorUserID = "actor_user_id"
        case actorDisplayName = "actor_display_name"
        case actorUsername = "actor_username"
        case actorAvatarURL = "actor_avatar_url"
        case title
        case body
        case visitID = "visit_id"
        case commentID = "comment_id"
        case cafeListID = "cafe_list_id"
        case friendRequestID = "friend_request_id"
        case deepLink = "deep_link"
        case canOpenVisit = "can_open_visit"
        case canRemoveTag = "can_remove_tag"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    var displayName: String {
        let trimmed = actorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : "@\(actorUsername)"
    }

    var createdDate: Date {
        ActivityDateParser.date(from: createdAt) ?? .distantPast
    }

    var isRead: Bool { readAt != nil }

    var destination: ActivityDeepLinkDestination? {
        guard let url = URL(string: deepLink) else { return nil }
        return ActivityDeepLinkDestination.resolve(url)
    }
}

struct ActivityNotificationPreferences: Codable, Equatable {
    var pushEnabled: Bool
    var friendPosts: Bool
    var tags: Bool
    var collaborativeListInvitations: Bool
    var likes: Bool
    var comments: Bool
    var reactions: Bool
    var friendRequests: Bool
    let updatedAt: String?

    static let alphaDefaults = ActivityNotificationPreferences(
        pushEnabled: true,
        friendPosts: true,
        tags: true,
        collaborativeListInvitations: true,
        likes: true,
        comments: true,
        reactions: true,
        friendRequests: true,
        updatedAt: nil
    )

    enum CodingKeys: String, CodingKey {
        case pushEnabled = "push_enabled"
        case friendPosts = "friend_posts"
        case tags
        case collaborativeListInvitations = "collaborative_list_invitations"
        case likes
        case comments
        case reactions
        case friendRequests = "friend_requests"
        case updatedAt = "updated_at"
    }
}

enum ActivityDeepLinkDestination: Codable, Hashable {
    case center
    case visit(UUID)
    case profile(UUID)
    case collaborativeLists

    static func resolve(_ url: URL) -> ActivityDeepLinkDestination? {
        guard url.scheme?.lowercased() == "mugshot",
              url.host?.lowercased() == "activity" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first else { return .center }
        switch first.lowercased() {
        case "visit":
            guard components.count == 2, let id = UUID(uuidString: components[1]) else {
                return nil
            }
            return .visit(id)
        case "people":
            guard components.count == 2, let id = UUID(uuidString: components[1]) else {
                return nil
            }
            return .profile(id)
        case "lists":
            return components.count == 1 ? .collaborativeLists : nil
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .center:
            URL(string: "mugshot://activity")!
        case .visit(let id):
            URL(string: "mugshot://activity/visit/\(id.uuidString.lowercased())")!
        case .profile(let id):
            URL(string: "mugshot://activity/people/\(id.uuidString.lowercased())")!
        case .collaborativeLists:
            URL(string: "mugshot://activity/lists")!
        }
    }
}

struct PendingActivityRoute: Codable, Equatable, Identifiable {
    let id: UUID
    let accountID: UUID
    let destination: ActivityDeepLinkDestination

    init(
        id: UUID = UUID(),
        accountID: UUID,
        destination: ActivityDeepLinkDestination
    ) {
        self.id = id
        self.accountID = accountID
        self.destination = destination
    }
}

struct ActivityPushRouteEnvelope: Equatable {
    let accountID: UUID
    let destination: ActivityDeepLinkDestination

    static func resolve(userInfo: [AnyHashable: Any]) -> ActivityPushRouteEnvelope? {
        guard let payload = userInfo["mugshot"] as? [String: Any],
              let rawRecipient = payload["recipient_id"] as? String,
              let accountID = UUID(uuidString: rawRecipient),
              let rawLink = payload["deep_link"] as? String,
              let url = URL(string: rawLink),
              let destination = ActivityDeepLinkDestination.resolve(url) else {
            return nil
        }
        return ActivityPushRouteEnvelope(
            accountID: accountID,
            destination: destination
        )
    }
}

enum ActivityPushCapability: Equatable {
    case unavailable(String)
    case configured(environment: String)

    var isConfigured: Bool {
        if case .configured = self { true } else { false }
    }
}

enum ActivityPushPermissionState: String, Equatable {
    case unsupported
    case notRequested
    case denied
    case authorized
    case provisional
    case unavailable
}

enum ActivityRegistrationState: Equatable {
    case idle
    case registering
    case registered
    case failed(String)
}

enum ActivityCenterLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

private enum ActivityDateParser {
    private static let lock = NSLock()
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from value: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return fractional.date(from: value) ?? standard.date(from: value)
    }
}
