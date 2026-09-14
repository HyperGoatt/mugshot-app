import Foundation
import Supabase

struct ContentScreeningItem: Decodable, Identifiable {
    let subject_kind: String
    let subject_id: UUID
    let revision: UUID
    let state: String
    let reason: String?
    let review_reason: String?
    let appeal_requested_at: String?
    let updated_at: String
    let self_review_conflict: Bool?
    let payload: Payload?
    let history: [ReviewEvent]?
    let evidence: Evidence?

    struct Evidence: Decodable {
        let categories: [String: Bool]?
        let diagnostics: Diagnostic?
        struct Diagnostic: Decodable { let stage: String?; let http_status: Int?; let error_code: String?; let request_id: String? }
    }
    let media_urls: [String?]?

    struct Payload: Decodable {
        let text: String
        let images: [String]
    }

    struct ReviewEvent: Decodable {
        let decision: String
        let reason: String
        let created_at: String
    }

    var id: String { "\(subject_kind)/\(subject_id)/\(revision)" }
    var title: String {
        switch subject_kind {
        case "user": "Profile"
        case "visit": "Mugshot"
        case "comment", "list_comment": "Comment"
        case "list": "Cafe list"
        case "list_item": "List note"
        case "recipe": "Recipe"
        case "recommendation": "Recommendation"
        default: "Shared content"
        }
    }
    var isTechnicalFailure: Bool { state == "service_error" || (state != "approved" && ["invalid_input", "provider_configuration", "invalid_response", "provider_unavailable", "screening_unavailable"].contains(reason ?? "")) }
    var stateTitle: String {
        if isTechnicalFailure { return state == "pending" ? "Checking sharing · retrying" : "Sharing check delayed" }
        return switch state {
        case "approved": "Screening passed"
        case "rejected": "Not shared"
        case "needs_review": "Awaiting review"
        default: "Checking sharing"
        }
    }
}

/// Responses are held in memory only and fenced to the signed-in account.
final class ContentScreeningService {
    private let client: SupabaseClient
    private let accountID: UUID

    init(accountID: UUID) throws {
        self.client = try SupabaseClientProvider.shared.client()
        self.accountID = accountID
    }

    private func checkAccount() throws {
        guard client.auth.currentUser?.id == accountID else {
            throw SocialSafetyServiceError.accountScopeChanged
        }
        try Task.checkCancellation()
    }

    func status() async throws -> [ContentScreeningItem] {
        try checkAccount()
        let result: [ContentScreeningItem] = try await client.rpc(
            "my_screening_status_v1", params: ["p_limit": 100]
        ).execute().value
        try checkAccount()
        return result
    }

    func role() async throws -> String? {
        try checkAccount()
        let result: String? = try await client.rpc("get_my_moderation_role_v1").execute().value
        try checkAccount()
        return result
    }

    func queue(state: String, after item: ContentScreeningItem?) async throws -> [ContentScreeningItem] {
        struct Parameters: Encodable {
            let p_limit = 25
            let p_state: String
            let p_cursor: [String: String]?
        }
        try checkAccount()
        let cursor = item.map { ["updated_at": $0.updated_at, "subject_kind": $0.subject_kind,
                                 "subject_id": $0.subject_id.uuidString] }
        let result: [ContentScreeningItem] = try await client.rpc(
            "list_screening_review_v1", params: Parameters(p_state: state, p_cursor: cursor)
        ).execute().value
        try checkAccount()
        return result
    }

    func preview(_ item: ContentScreeningItem) async throws -> ContentScreeningItem {
        try checkAccount()
        let result: ContentScreeningItem = try await client.functions.invoke(
            "moderation-review", options: FunctionInvokeOptions(body: [
                "p_kind": item.subject_kind, "p_id": item.subject_id.uuidString,
                "p_revision": item.revision.uuidString
            ])
        )
        try checkAccount()
        return result
    }

    func decide(_ item: ContentScreeningItem, decision: String?, reason: String) async throws -> Bool {
        try checkAccount()
        var params = ["p_kind": item.subject_kind, "p_id": item.subject_id.uuidString,
                      "p_revision": item.revision.uuidString, "p_reason": reason,
                      "p_actor": accountID.uuidString]
        if let decision { params["p_decision"] = decision }
        let applied: Bool = try await client.rpc(
            decision == nil ? "request_screening_review_v1" : "review_screening_v1",
            params: params
        ).execute().value
        try checkAccount()
        return applied
    }

    func cases(kind: String, status: String, after item: ModerationReviewCase?) async throws -> [ModerationReviewCase] {
        struct Parameters: Encodable {
            let p_kind: String
            let p_status: String
            let p_cursor: [String: String]?
        }
        try checkAccount()
        let result: [ModerationReviewCase] = try await client.rpc(
            "list_moderation_cases_v1", params: Parameters(
                p_kind: kind, p_status: status,
                p_cursor: item.map { ["created_at": $0.created_at, "id": $0.id.uuidString] }
            )
        ).execute().value
        try checkAccount()
        return result
    }

    func reviewCase(_ item: ModerationReviewCase) async throws -> ModerationReviewCase? {
        try checkAccount()
        let result: ModerationReviewCase? = try await client.rpc(
            "get_moderation_case_v1", params: ["p_kind": item.kind, "p_id": item.id.uuidString]
        ).execute().value
        try checkAccount()
        return result
    }

    func reportContent(_ reportID: UUID) async throws -> ContentScreeningItem? {
        try checkAccount()
        let result: ContentScreeningItem? = try await client.rpc(
            "get_report_screening_target_v1", params: ["p_report_id": reportID.uuidString]
        ).execute().value
        try checkAccount()
        return result
    }

    func resolveCase(_ item: ModerationReviewCase, status: String, resolution: String, action: String, endsAt: Date?) async throws -> Bool {
        try checkAccount()
        var params = ["p_expected_status": item.status, "p_new_status": status,
                      "p_resolution": resolution, "p_actor": accountID.uuidString]
        if item.kind == "report" {
            params["p_report_id"] = item.id.uuidString
            params["p_action"] = action
        } else {
            params["p_appeal_id"] = item.id.uuidString
            if let endsAt { params["p_modified_ends_at"] = ISO8601DateFormatter().string(from: endsAt) }
        }
        let result: Bool = try await client.rpc(
            item.kind == "report" ? "review_report_v2" : "review_moderation_appeal_v2",
            params: params
        ).execute().value
        try checkAccount()
        return result
    }
}

struct ModerationReviewCase: Decodable, Identifiable {
    let id: UUID
    let kind: String
    let status: String
    let created_at: String
    let reason: String
    let statement: String?
    let resolution: String?
    let target_kind: String
    let target_id: UUID
    let subject_text: String?
    let action_kind: String?
    let ends_at: String?
    let revoked_at: String?
    let self_review_conflict: Bool
    let history: [Event]

    struct Event: Decodable {
        let event_kind: String
        let internal_note: String?
        let created_at: String
    }

    var isOpen: Bool { ["pending", "reviewing"].contains(status) }
    var title: String {
        if kind == "appeal" { return "Enforcement appeal" }
        switch target_kind {
        case "visit": return "Mugshot report"
        case "comment", "cafe_list_comment": return "Comment report"
        default: return "Account report"
        }
    }
}
