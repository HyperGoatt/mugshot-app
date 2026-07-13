import CoreLocation
import Foundation
import Supabase

final class SocialDiscoveryService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func searchPeople(query: String, limit: Int = 20) async throws -> [PeopleSearchResult] {
        try await client.rpc(
            "search_users",
            params: PeopleSearchParameters(pQuery: query, pLimit: limit)
        ).execute().value
    }

    func connections(kind: String, limit: Int = 50) async throws -> [SocialConnection] {
        try await client.rpc(
            "list_social_connections",
            params: SocialListParameters(pKind: kind, pLimit: limit)
        ).execute().value
    }

    func discovery(
        section: DiscoverySection,
        location: CLLocation?,
        radiusKM: Double,
        limit: Int = 20,
        after: DiscoveryCafe? = nil
    ) async throws -> [DiscoveryCafe] {
        try await client.rpc(
            "discover_cafes",
            params: DiscoveryParameters(
                pSection: section.rawValue,
                pLatitude: location?.coordinate.latitude,
                pLongitude: location?.coordinate.longitude,
                pRadiusKM: radiusKM,
                pLimit: limit,
                pAfterScore: after?.rankingScore,
                pAfterID: after?.id
            )
        ).execute().value
    }

    func publicProfile(userID: UUID) async throws -> PublicProfilePayload {
        try await client.rpc(
            "get_public_profile",
            params: ["p_user_id": userID]
        ).execute().value
    }

    func sendFriendRequest(to userID: UUID) async throws {
        try await client.rpc("send_friend_request", params: ["p_target_user_id": userID]).execute()
    }

    func respond(to requestID: UUID, accept: Bool) async throws {
        try await client.rpc(
            "respond_friend_request",
            params: FriendResponseParameters(pRequestID: requestID, pAccept: accept)
        ).execute()
    }

    func cancel(requestID: UUID) async throws {
        try await client.rpc("cancel_friend_request", params: ["p_request_id": requestID]).execute()
    }

    func removeFriend(userID: UUID) async throws {
        try await client.rpc("remove_friendship", params: ["p_other_user_id": userID]).execute()
    }

    func block(userID: UUID) async throws {
        try await client.rpc("block_user", params: ["p_blocked_user_id": userID]).execute()
    }

    func unblock(userID: UUID) async throws {
        try await client.rpc("unblock_user", params: ["p_blocked_user_id": userID]).execute()
    }

    func report(
        reason: ReportReason,
        details: String?,
        userID: UUID? = nil,
        visitID: UUID? = nil,
        commentID: UUID? = nil
    ) async throws {
        try await client.rpc(
            "submit_report",
            params: ReportParameters(
                pReason: reason.rawValue,
                pDetails: details,
                pTargetUserID: userID,
                pTargetVisitID: visitID,
                pTargetCommentID: commentID
            )
        ).execute()
    }
}

private struct PeopleSearchParameters: Encodable {
    let pQuery: String
    let pLimit: Int
    enum CodingKeys: String, CodingKey { case pQuery = "p_query"; case pLimit = "p_limit" }
}

private struct SocialListParameters: Encodable {
    let pKind: String
    let pLimit: Int
    enum CodingKeys: String, CodingKey { case pKind = "p_kind"; case pLimit = "p_limit" }
}

private struct DiscoveryParameters: Encodable {
    let pSection: String
    let pLatitude: Double?
    let pLongitude: Double?
    let pRadiusKM: Double
    let pLimit: Int
    let pAfterScore: Double?
    let pAfterID: UUID?
    enum CodingKeys: String, CodingKey {
        case pSection = "p_section"
        case pLatitude = "p_latitude"
        case pLongitude = "p_longitude"
        case pRadiusKM = "p_radius_km"
        case pLimit = "p_limit"
        case pAfterScore = "p_after_score"
        case pAfterID = "p_after_id"
    }
}

private struct FriendResponseParameters: Encodable {
    let pRequestID: UUID
    let pAccept: Bool
    enum CodingKeys: String, CodingKey { case pRequestID = "p_request_id"; case pAccept = "p_accept" }
}

private struct ReportParameters: Encodable {
    let pReason: String
    let pDetails: String?
    let pTargetUserID: UUID?
    let pTargetVisitID: UUID?
    let pTargetCommentID: UUID?
    enum CodingKeys: String, CodingKey {
        case pReason = "p_reason"
        case pDetails = "p_details"
        case pTargetUserID = "p_target_user_id"
        case pTargetVisitID = "p_target_visit_id"
        case pTargetCommentID = "p_target_comment_id"
    }
}
