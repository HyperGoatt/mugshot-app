import Foundation

enum MugshotActivityKind: String, Codable, CaseIterable {
    case friendPost = "friend_post"
    case tag
    case sharedMugshotInvitation = "shared_mugshot_invitation"
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
        case .sharedMugshotInvitation: "person.2.wave.2.fill"
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
    let sharedMemoryID: UUID?
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
        case sharedMemoryID = "shared_memory_id"
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
    var sharedMugshotInvitations: Bool
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
        sharedMugshotInvitations: true,
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
        case sharedMugshotInvitations = "shared_mugshot_invitations"
        case collaborativeListInvitations = "collaborative_list_invitations"
        case likes
        case comments
        case reactions
        case friendRequests = "friend_requests"
        case updatedAt = "updated_at"
    }
}

struct SharedMugshotMembership: Decodable, Identifiable, Equatable {
    let id: UUID
    let sharedMemoryID: UUID
    let status: String
    let inviterID: UUID?
    let inviterDisplayName: String?
    let inviterUsername: String?
    let inviterAvatarURL: String?
    let relationshipAvailable: Bool
    let contextType: String
    let cafeID: UUID?
    let locationLabel: String?
    let occurredAt: String
    let invitedAt: String
    let respondedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "membership_id"
        case sharedMemoryID = "shared_memory_id"
        case status
        case inviterID = "inviter_id"
        case inviterDisplayName = "inviter_display_name"
        case inviterUsername = "inviter_username"
        case inviterAvatarURL = "inviter_avatar_url"
        case relationshipAvailable = "relationship_available"
        case contextType = "context_type"
        case cafeID = "cafe_id"
        case locationLabel = "location_label"
        case occurredAt = "occurred_at"
        case invitedAt = "invited_at"
        case respondedAt = "responded_at"
    }

    var inviterLabel: String {
        if let name = inviterDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty { return name }
        if let username = inviterUsername, !username.isEmpty { return "@\(username)" }
        return "Unavailable account"
    }
}

struct OwnedSharedMugshot: Decodable, Identifiable, Equatable {
    let sharedMugshotID: UUID
    // The original source can disappear during account deletion while the
    // consented grouping safely transfers to another accepted participant.
    let sourceVisitID: UUID?
    let contextType: String
    let cafeID: UUID?
    let locationLabel: String?
    let occurredAt: String
    let createdAt: String
    let updatedAt: String

    var id: UUID { sharedMugshotID }

    enum CodingKeys: String, CodingKey {
        case sharedMugshotID = "shared_memory_id"
        case sourceVisitID = "source_visit_id"
        case contextType = "context_type"
        case cafeID = "cafe_id"
        case locationLabel = "location_label"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ManagedSharedMugshotInvitation: Decodable, Identifiable, Equatable {
    let id: UUID
    let userID: UUID?
    let displayName: String?
    let username: String?
    let avatarURL: String?
    let status: String
    let invitedAt: String
    let respondedAt: String?
    let leftAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "invitation_id"
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case status
        case invitedAt = "invited_at"
        case respondedAt = "responded_at"
        case leftAt = "left_at"
    }

    var personLabel: String {
        if let displayName = displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue {
            return displayName
        }
        if let username = username?.nonEmptyValue {
            return "@\(username)"
        }
        return "Unavailable account"
    }

    var canCancel: Bool { status == "pending" }
}

enum SharedMugshotContributionEligibility {
    static let maximumMomentDistance: TimeInterval = 12 * 60 * 60

    static func eligibleVisits(
        from visits: [RemoteVisitSummary],
        for membership: SharedMugshotMembership,
        ownerID: UUID
    ) -> [RemoteVisitSummary] {
        visits.filter {
            isEligible(
                visit: $0.visit,
                contextType: membership.contextType,
                cafeID: membership.cafeID,
                occurredAt: membership.occurredAt,
                ownerID: ownerID
            )
        }
    }

    static func isEligible(
        visit: SupabaseVisitRow,
        contextType: String,
        cafeID: UUID?,
        occurredAt: String,
        ownerID: UUID
    ) -> Bool {
        guard visit.userId == ownerID,
              visit.uploadState == VisitUploadState.complete.rawValue,
              visit.isCafeSessionPrimary,
              visit.journalContext == journalContext(for: contextType) else {
            return false
        }
        guard let sharedDate = ActivityDateParser.date(from: occurredAt),
              abs(visit.createdAtDate.timeIntervalSince(sharedDate))
                <= maximumMomentDistance else {
            return false
        }
        guard journalContext(for: contextType) == .cafe else { return true }
        return cafeID != nil && visit.cafeId == cafeID
    }

    private static func journalContext(for backendValue: String) -> JournalEntryContext {
        switch backendValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "home": .home
        case "recipe": .recipe
        case "elsewhere": .elsewhere
        default: .cafe
        }
    }
}

private extension String {
    var nonEmptyValue: String? { isEmpty ? nil : self }
}

enum ActivityDeepLinkDestination: Codable, Hashable {
    case center
    case visit(UUID)
    case profile(UUID)
    case sharedMugshots
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
        case "shared":
            return components.count == 1 ? .sharedMugshots : nil
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
        case .sharedMugshots:
            URL(string: "mugshot://activity/shared")!
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
