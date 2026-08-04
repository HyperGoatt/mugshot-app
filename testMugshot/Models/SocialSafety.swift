import Foundation

enum SocialSafetyTarget: Codable, Equatable, Hashable {
    case user(UUID)
    case visit(UUID)
    case comment(UUID)

    var kind: String {
        switch self {
        case .user: "user"
        case .visit: "visit"
        case .comment: "comment"
        }
    }

    var targetID: UUID {
        switch self {
        case .user(let id), .visit(let id), .comment(let id): id
        }
    }

    var reportLabel: String {
        switch self {
        case .user: "profile"
        case .visit: "sip"
        case .comment: "comment"
        }
    }
}

struct SafetyReportDetailsRequest: Identifiable, Equatable {
    let target: SocialSafetyTarget

    var id: String { "\(target.kind).\(target.targetID.uuidString)" }
}

struct SafetyReportConfirmationRequest: Identifiable, Equatable {
    let target: SocialSafetyTarget
    let reason: ReportReason
    let details: String?

    var id: String {
        "\(target.kind).\(target.targetID.uuidString).\(reason.rawValue)"
    }
}

enum SafetyReportDeliveryState: String, Codable, Equatable {
    case pending
    case submitted
    case failed
}

struct SafetyReportReceipt: Identifiable, Codable, Equatable {
    let clientReportID: UUID
    let accountID: UUID
    let target: SocialSafetyTarget
    let reason: ReportReason
    var details: String?
    var deliveryState: SafetyReportDeliveryState
    var serverReportID: UUID?
    var serverStatus: String?
    let createdAt: Date
    var updatedAt: Date

    var id: UUID { clientReportID }
}

enum SafetyReportSubmissionOutcome: Equatable {
    case submitted(SafetyReportReceipt)
    case failed(SafetyReportReceipt)
}

struct SafetyBlockResult: Decodable, Equatable {
    let blockerID: UUID
    let blockedID: UUID
    let blockedAt: String
    let severed: SafetyBlockConsequences

    enum CodingKeys: String, CodingKey {
        case blockerID = "blocker_id"
        case blockedID = "blocked_id"
        case blockedAt = "blocked_at"
        case severed
    }
}

struct SafetyBlockConsequences: Decodable, Equatable {
    let friendships: Int
    let friendRequests: Int
    let comments: Int
    let mentions: Int
    let likes: Int
    let reactions: Int
    let companions: Int
    let recommendations: Int
    let listMemberships: Int
    let sharedInvitations: Int
    let sharedMemories: Int?
    let savedRecipeCopies: Int?

    enum CodingKeys: String, CodingKey {
        case friendships
        case friendRequests = "friend_requests"
        case comments, mentions, likes, reactions, companions, recommendations
        case listMemberships = "list_memberships"
        case sharedInvitations = "shared_invitations"
        case sharedMemories = "shared_memories"
        case savedRecipeCopies = "saved_recipe_copies"
    }
}

enum SocialSafetyCopy {
    static let blockConsequences = "Blocking removes your friendship, interactions, tags, and pending invitations with this person. Their tag is removed from your private people recaps immediately. Each private journal stays unchanged. Choose whether Mugshot should also remove recipe copies you saved from them."
    static let unblockConsequences = "Unblocking lets this person appear in Mugshot again. It does not restore a friendship, interactions, tags, or invitations that were removed."
    static let reportPending = "Sending report…"
    static let reportSubmitted = "Report submitted."
    static let reportFailed = "Report delivery could not be confirmed. Retry to safely reuse the same report receipt."
}

extension ReportReason: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let reason = ReportReason(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown report reason."
            )
        }
        self = reason
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
