import Foundation
import Supabase

final class PeopleDiscoveryService {
    private let client: SupabaseClient
    private let configuration: MugshotShareConfiguration

    init(
        client: SupabaseClient,
        configuration: MugshotShareConfiguration = .load()
    ) {
        self.client = client
        self.configuration = configuration
    }

    func capabilities() async throws -> PeopleDiscoveryCapabilities {
        let rows: [PeopleDiscoveryCapabilities] = try await client.rpc(
            "get_people_discovery_capabilities_v1"
        ).execute().value
        return rows.first ?? .unavailable
    }

    func search(
        query: String,
        limit: Int = 20,
        after: PeopleSearchResult? = nil
    ) async throws -> [PeopleSearchResult] {
        try await client.rpc(
            "search_people_v2",
            params: PeopleSearchV2Parameters(
                pQuery: query,
                pLimit: limit,
                pAfterRank: after?.rankBucket,
                pAfterScore: after?.matchScore,
                pAfterUsername: after?.username,
                pAfterID: after?.id
            )
        ).execute().value
    }

    func suggestions(limit: Int = 10) async throws -> [PeopleSuggestion] {
        try await client.rpc(
            "get_people_suggestions_v1", params: ["p_limit": limit]
        ).execute().value
    }

    func hub(pageSize: Int = 20) async throws -> PeopleHubPayload {
        try await client.rpc(
            "get_people_hub_v1", params: ["p_page_size": min(max(pageSize, 1), 20)]
        ).execute().value
    }

    func dismissSuggestion(userID: UUID, undo: Bool = false) async throws {
        try await client.rpc(
            "dismiss_people_suggestion_v1",
            params: DismissSuggestionParameters(pCandidateID: userID, pUndo: undo)
        ).execute()
    }

    func preferences() async throws -> PeopleDiscoveryPreferences {
        let rows: [PeopleDiscoveryPreferences] = try await client.rpc(
            "get_discovery_preferences_v1"
        ).execute().value
        return rows.first ?? PeopleDiscoveryPreferences(
            emailDiscoverable: false,
            suggestionsEnabled: false,
            mutualExplanationsEnabled: false,
            consentVersion: nil,
            version: 0,
            hasDiscoveryEmail: false
        )
    }

    func savePreferences(_ value: PeopleDiscoveryPreferences) async throws -> PeopleDiscoveryPreferences {
        let rows: [PeopleDiscoveryPreferences] = try await client.rpc(
            "set_discovery_preferences_v1",
            params: DiscoveryPreferenceParameters(value)
        ).execute().value
        guard let saved = rows.first else { throw PeopleDiscoveryError.invalidResponse }
        if saved.emailDiscoverable {
            struct EnrollmentRequest: Encodable {
                let action = "enroll_email"
                let consentVersion = 1
                enum CodingKeys: String, CodingKey {
                    case action
                    case consentVersion = "consent_version"
                }
            }
            struct EnrollmentResponse: Decodable { let enrolled: Bool }
            let response: EnrollmentResponse
            do {
                response = try await client.functions.invoke(
                    "match-selected-contacts-v1",
                    options: FunctionInvokeOptions(method: .post, body: EnrollmentRequest())
                )
                guard response.enrolled else { throw PeopleDiscoveryError.emailEnrollmentFailed }
            } catch {
                var rollback = saved
                rollback.emailDiscoverable = false
                _ = try? await client.rpc(
                    "set_discovery_preferences_v1",
                    params: DiscoveryPreferenceParameters(rollback)
                ).execute()
                throw error
            }
            return PeopleDiscoveryPreferences(
                emailDiscoverable: saved.emailDiscoverable,
                suggestionsEnabled: saved.suggestionsEnabled,
                mutualExplanationsEnabled: saved.mutualExplanationsEnabled,
                consentVersion: saved.consentVersion,
                version: saved.version,
                hasDiscoveryEmail: true
            )
        }
        return saved
    }

    func match(_ contacts: [SelectedContactForDiscovery]) async throws -> [ContactDiscoveryResult] {
        let request = ContactMatchRequest(
            action: "match",
            consentVersion: 1,
            items: contacts.map {
                ContactMatchRequest.Item(itemKey: $0.id, emails: $0.emails)
            }
        )
        let response: ContactMatchResponse = try await client.functions.invoke(
            "match-selected-contacts-v1",
            options: FunctionInvokeOptions(method: .post, body: request)
        )
        let matchesByKey = Dictionary(uniqueKeysWithValues: response.items.map { ($0.itemKey, $0.matches) })
        return contacts.map {
            ContactDiscoveryResult(id: $0.id, contact: $0, matches: matchesByKey[$0.id] ?? [])
        }
    }

    func createInvite(requestNonce: UUID = UUID()) async throws -> FriendInvite {
        let rows: [FriendInvite] = try await client.rpc(
            "create_friend_invite_v1",
            params: ["p_request_nonce": requestNonce.uuidString]
        ).execute().value
        guard let invite = rows.first else { throw PeopleDiscoveryError.invalidResponse }
        return invite
    }

    func inviteURL(_ invite: FriendInvite) -> URL? {
        configuration.publicBaseURL?
            .appendingPathComponent("invite", isDirectory: true)
            .appendingPathComponent(invite.token, isDirectory: false)
    }

    func resolveInvite(secret: String) async throws -> ResolvedFriendInvite? {
        let rows: [ResolvedFriendInvite] = try await client.rpc(
            "resolve_friend_invite_v1", params: ["p_secret": secret]
        ).execute().value
        return rows.first
    }

    func sendFriendRequest(
        to userID: UUID,
        source: PeopleDiscoverySource,
        inviteID: UUID? = nil,
        requestNonce: UUID = UUID()
    ) async throws {
        try await client.rpc(
            "send_friend_request_v2",
            params: SendAttributedFriendRequestParameters(
                pTargetUserID: userID,
                pSource: source.rawValue,
                pRequestNonce: requestNonce,
                pInviteID: inviteID
            )
        ).execute()
    }

    func firstWeekPromptEligible() async throws -> Bool {
        try await client.rpc("people_prompt_eligibility_v1").execute().value
    }

    func consumeFirstWeekPrompt(outcome: String) async throws {
        try await client.rpc(
            "consume_people_prompt_v1", params: ["p_outcome": outcome]
        ).execute()
    }
}

enum PeopleDiscoverySource: String, Codable, CaseIterable {
    case feed, friendsEmpty = "friends_empty", profile, peopleHub = "people_hub"
    case searchEmpty = "search_empty", firstWeek = "first_week"
    case sharedPost = "shared_post", sharedList = "shared_list"
    case profileLink = "profile_link", inviteLink = "invite_link"
    case inviteCode = "invite_code", contacts, search, suggestion
}

enum PeopleDiscoveryError: Error { case invalidResponse, emailEnrollmentFailed }

private struct PeopleSearchV2Parameters: Encodable {
    let pQuery: String
    let pLimit: Int
    let pAfterRank: Int?
    let pAfterScore: Double?
    let pAfterUsername: String?
    let pAfterID: UUID?
    enum CodingKeys: String, CodingKey {
        case pQuery = "p_query", pLimit = "p_limit"
        case pAfterRank = "p_after_rank", pAfterScore = "p_after_score"
        case pAfterUsername = "p_after_username", pAfterID = "p_after_id"
    }
}

private struct DismissSuggestionParameters: Encodable {
    let pCandidateID: UUID
    let pUndo: Bool
    enum CodingKeys: String, CodingKey { case pCandidateID = "p_candidate_id", pUndo = "p_undo" }
}

private struct DiscoveryPreferenceParameters: Encodable {
    let pEmailDiscoverable: Bool
    let pSuggestionsEnabled: Bool
    let pMutualExplanationsEnabled: Bool
    let pConsentVersion = 1
    let pExpectedVersion: Int64?
    init(_ value: PeopleDiscoveryPreferences) {
        pEmailDiscoverable = value.emailDiscoverable
        pSuggestionsEnabled = value.suggestionsEnabled
        pMutualExplanationsEnabled = value.mutualExplanationsEnabled
        pExpectedVersion = value.version == 0 ? nil : value.version
    }
    enum CodingKeys: String, CodingKey {
        case pEmailDiscoverable = "p_email_discoverable"
        case pSuggestionsEnabled = "p_suggestions_enabled"
        case pMutualExplanationsEnabled = "p_mutual_explanations_enabled"
        case pConsentVersion = "p_consent_version"
        case pExpectedVersion = "p_expected_version"
    }
}

private struct ContactMatchRequest: Encodable {
    struct Item: Encodable {
        let itemKey: String
        let emails: [String]
        enum CodingKeys: String, CodingKey { case itemKey = "item_key", emails }
    }
    let action: String
    let consentVersion: Int
    let items: [Item]
    enum CodingKeys: String, CodingKey {
        case action, items
        case consentVersion = "consent_version"
    }
}

private struct ContactMatchResponse: Decodable {
    struct Item: Decodable {
        let itemKey: String
        let matches: [ContactDiscoveryMatch]
        enum CodingKeys: String, CodingKey { case itemKey = "item_key", matches }
    }
    let items: [Item]
}

private struct SendAttributedFriendRequestParameters: Encodable {
    let pTargetUserID: UUID
    let pSource: String
    let pRequestNonce: UUID
    let pInviteID: UUID?
    enum CodingKeys: String, CodingKey {
        case pTargetUserID = "p_target_user_id", pSource = "p_source"
        case pRequestNonce = "p_request_nonce", pInviteID = "p_invite_id"
    }
}
