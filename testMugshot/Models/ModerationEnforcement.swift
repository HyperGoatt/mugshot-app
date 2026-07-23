import Foundation

enum ModerationActionKind: String, Codable, Equatable {
    case warning
    case contentHidden = "content_hidden"
    case socialRestricted = "social_restricted"
    case accountSuspended = "account_suspended"

    var title: String {
        switch self {
        case .warning:
            "Account warning"
        case .contentHidden:
            "Content hidden"
        case .socialRestricted:
            "Social features limited"
        case .accountSuspended:
            "Account sharing suspended"
        }
    }

    var systemImage: String {
        switch self {
        case .warning: "exclamationmark.triangle.fill"
        case .contentHidden: "eye.slash.fill"
        case .socialRestricted: "person.2.slash.fill"
        case .accountSuspended: "hand.raised.fill"
        }
    }

    var impact: String {
        switch self {
        case .warning:
            "This warning does not limit a feature by itself."
        case .contentHidden:
            "This content is hidden from other people. Your private journal remains available."
        case .socialRestricted:
            "Posting and social interactions are unavailable while this is active. Your private journal, data export, account controls, and appeal access remain available."
        case .accountSuspended:
            "Your shared profile and social activity are unavailable while this is active. Your private journal, data export, account controls, and appeal access remain available."
        }
    }
}

enum ModerationAppealStatus: String, Codable, Equatable {
    case pending
    case reviewing
    case upheld
    case modified
    case reversed

    var title: String {
        switch self {
        case .pending: "Submitted"
        case .reviewing: "Under review"
        case .upheld: "Decision upheld"
        case .modified: "Decision changed"
        case .reversed: "Decision reversed"
        }
    }

    var isFinal: Bool {
        switch self {
        case .pending, .reviewing: false
        case .upheld, .modified, .reversed: true
        }
    }
}

struct ModerationEnforcementAction: Codable, Identifiable, Equatable {
    let actionID: UUID
    let actionKind: ModerationActionKind
    let subjectKind: String
    let subjectID: UUID
    let reasonCode: String
    let startsAt: String
    let endsAt: String?
    let revokedAt: String?
    let isActive: Bool
    let appealEligible: Bool
    let appealID: UUID?
    let appealStatus: ModerationAppealStatus?
    let appealSubmittedAt: String?
    let appealReviewedAt: String?
    let appealResolutionSummary: String?

    var id: UUID { actionID }

    enum CodingKeys: String, CodingKey {
        case actionID = "action_id"
        case actionKind = "action_kind"
        case subjectKind = "subject_kind"
        case subjectID = "subject_id"
        case reasonCode = "reason_code"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case revokedAt = "revoked_at"
        case isActive = "is_active"
        case appealEligible = "appeal_eligible"
        case appealID = "appeal_id"
        case appealStatus = "appeal_status"
        case appealSubmittedAt = "appeal_submitted_at"
        case appealReviewedAt = "appeal_reviewed_at"
        case appealResolutionSummary = "appeal_resolution_summary"
    }

    var reasonTitle: String {
        reasonCode
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var subjectTitle: String {
        switch subjectKind {
        case "visit": "MugShot post"
        case "comment": "Comment"
        default: "Account"
        }
    }

    var canAppeal: Bool {
        appealEligible
    }

    var isCurrentlyActive: Bool {
        guard revokedAt == nil,
              let starts = ModerationDateParser.date(from: startsAt),
              starts <= Date() else { return false }
        if let ends = ModerationDateParser.date(from: endsAt) {
            return ends > Date()
        }
        return true
    }
}

struct ModerationAppealRPCReceipt: Decodable, Equatable {
    let appealID: UUID
    let actionID: UUID
    let status: ModerationAppealStatus
    let submittedAt: String
    let reviewedAt: String?
    let resolutionSummary: String?

    enum CodingKeys: String, CodingKey {
        case appealID = "appeal_id"
        case actionID = "action_id"
        case status
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case resolutionSummary = "resolution_summary"
    }
}

struct PendingModerationAppeal: Codable, Identifiable, Equatable {
    let clientAppealID: UUID
    let accountID: UUID
    let actionID: UUID
    let statement: String
    let createdAt: Date

    var id: UUID { clientAppealID }
}

enum ModerationAppealSubmissionOutcome: Equatable {
    case submitted(ModerationAppealRPCReceipt)
    case deliveryUnconfirmed(PendingModerationAppeal)
}

struct SafeReportReceipt: Decodable, Identifiable, Equatable {
    let reportID: UUID
    let targetKind: String
    let targetID: UUID
    let reason: ReportReason
    let status: String
    let createdAt: String
    let closedAt: String?
    let resolutionCode: String?

    var id: UUID { reportID }

    enum CodingKeys: String, CodingKey {
        case reportID = "report_id"
        case targetKind = "target_kind"
        case targetID = "target_id"
        case reason
        case status
        case createdAt = "created_at"
        case closedAt = "closed_at"
        case resolutionCode = "resolution_code"
    }
}

enum ModerationDateParser {
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

    static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return fractional.date(from: value) ?? standard.date(from: value)
    }
}
