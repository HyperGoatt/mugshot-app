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

    func companionSuggestions(limit: Int = 50) async throws -> [SipCompanionSuggestion] {
        try await client.rpc(
            "companion_suggestions",
            params: ["p_limit": limit]
        ).execute().value
    }

    /// Ordinary attribution. This does not grant post access or shared
    /// ownership and intentionally does not require the tagged account's
    /// consent.
    func setVisitTags(_ userIDs: [UUID], for visitID: UUID) async throws {
        try await client.rpc(
            "set_visit_tags_v1",
            params: VisitTagParameters(pVisitID: visitID, pTaggedUserIDs: userIDs)
        ).execute()
    }

    /// Creates pending co-ownership invitations only after the source post is
    /// complete. Invitees remain independent until they explicitly accept.
    @discardableResult
    func createSharedMemoryInvitations(
        for visitID: UUID,
        inviteeIDs: [UUID]
    ) async throws -> UUID {
        try await client.rpc(
            "create_shared_memory_invitations_v1",
            params: SharedMemoryInvitationParameters(
                pVisitID: visitID,
                pInviteeIDs: inviteeIDs
            )
        ).execute().value
    }

    /// Resolves only the viewer-safe recipe reference, then applies immutable
    /// provenance before widening the recipe's independent audience. The
    /// client never reads raw recipe instructions to perform this handoff.
    @discardableResult
    func configureRecipePublication(
        for visitID: UUID,
        contract: SipRecipePublicationContract
    ) async throws -> UUID {
        guard contract.requirement == .ready else {
            throw SocialDiscoveryServiceError.invalidRecipePublicationContract
        }
        let reference: RecipeProjectionReference? = try await client.rpc(
            "get_recipe_projection_for_visit_v1",
            params: ["p_visit_id": visitID]
        ).execute().value
        guard let recipeVersionID = reference?.recipeVersionID else {
            throw SocialDiscoveryServiceError.recipeProjectionUnavailable
        }

        try await client.rpc(
            "configure_recipe_source_rights_v1",
            params: RecipeSourceRightsParameters(
                pRecipeVersionID: recipeVersionID,
                pSourceKind: contract.sourceKind.rawValue,
                pRedistributionAllowed: contract.redistributionAllowed
                    && contract.sourceKind.permitsRedistribution,
                pSourceRecipeVersionID: contract.sourceRecipeVersionID
            )
        ).execute()
        try await client.rpc(
            "set_recipe_visibility_v1",
            params: RecipeVisibilityParameters(
                pRecipeVersionID: recipeVersionID,
                pVisibility: contract.visibility.supabaseValue,
                pAcknowledgesPublicReuse: contract.acknowledgesPublicReuse
            )
        ).execute()
        return recipeVersionID
    }

    /// Saves an immutable, private, attributed copy of a reusable recipe.
    /// The server resolves and copies the allowlisted source payload; the
    /// client sends only the source version and the viewer's chosen label.
    @discardableResult
    func saveRecipeAdaptation(
        sourceRecipeVersionID: UUID,
        name: String,
        versionLabel: String = "Adapted"
    ) async throws -> UUID {
        guard let cleanName = name.remoteTrimmedNonEmpty,
              cleanName.count <= 120 else {
            throw SocialDiscoveryServiceError.invalidRecipeAdaptationName
        }
        return try await client.rpc(
            "save_recipe_adaptation_v1",
            params: SaveRecipeAdaptationParameters(
                pSourceRecipeVersionID: sourceRecipeVersionID,
                pName: cleanName,
                pVersionLabel: versionLabel
            )
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

    func publicDiscovery(
        section: DiscoverySection,
        location: CLLocation?,
        radiusKM: Double,
        limit: Int = 20,
        after: DiscoveryCafe? = nil
    ) async throws -> [DiscoveryCafe] {
        try await client.rpc(
            "discover_public_cafes",
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

    func friendCafeDiscovery(
        location: CLLocation?,
        radiusKM: Double,
        limit: Int = 20,
        after: DiscoveryCafe? = nil
    ) async throws -> [DiscoveryCafe] {
        try await client.rpc(
            "discover_friend_cafes",
            params: FriendCafeDiscoveryParameters(
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

    func cafeLists() async throws -> [CafeListRecord] {
        try await client
            .from("cafe_lists")
            .select("id,owner_id,title,description,visibility,system_kind,created_at,updated_at")
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func createCafeList(
        title: String,
        description: String? = nil,
        visibility: CafeListVisibility
    ) async throws -> CafeListRecord {
        try await client.rpc(
            "create_cafe_list",
            params: CreateCafeListParameters(
                pTitle: title,
                pDescription: description,
                pVisibility: visibility.rawValue
            )
        ).execute().value
    }

    func addCafe(_ cafeID: UUID, to listID: UUID, note: String? = nil) async throws {
        try await client.rpc(
            "add_cafe_list_item_v2",
            params: AddCafeListItemParameters(pListID: listID, pCafeID: cafeID, pNote: note)
        ).execute()
    }

    func removeCafeListItem(_ itemID: UUID) async throws {
        try await client.rpc("remove_cafe_list_item", params: ["p_item_id": itemID]).execute()
    }

    func moveCafeListItem(_ itemID: UUID, to position: Int) async throws {
        try await client.rpc(
            "move_cafe_list_item_v2",
            params: MoveCafeListItemParameters(pItemID: itemID, pPosition: position)
        ).execute()
    }

    func inviteFriend(_ userID: UUID, to listID: UUID, role: String) async throws -> CafeListMemberRecord {
        try await client.rpc(
            "invite_cafe_list_member",
            params: InviteCafeListMemberParameters(pListID: listID, pUserID: userID, pRole: role)
        ).execute().value
    }

    func respondToListInvitation(listID: UUID, accept: Bool) async throws {
        try await client.rpc(
            "respond_cafe_list_invitation",
            params: ListInvitationResponseParameters(pListID: listID, pAccept: accept)
        ).execute()
    }

    func recommendations() async throws -> [TrustedRecommendation] {
        try await client
            .from("trusted_recommendations")
            .select("id,sender_id,recipient_id,target_kind,target_cafe_id,target_visit_id,target_recipe_version_id,note,status,created_at,updated_at")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func sharedRecipes() async throws -> [SharedRecipeRecord] {
        try await client.rpc("list_shared_recipes").execute().value
    }

    func recommend(
        to friendID: UUID,
        kind: TrustedRecommendationKind,
        targetID: UUID,
        note: String?
    ) async throws -> TrustedRecommendation {
        try await client.rpc(
            "send_trusted_recommendation",
            params: TrustedRecommendationParameters(
                pRecipientID: friendID,
                pTargetKind: kind.rawValue,
                pTargetID: targetID,
                pNote: note
            )
        ).execute().value
    }

    func updateRecommendation(_ id: UUID, status: String) async throws -> TrustedRecommendation {
        try await client.rpc(
            "update_trusted_recommendation",
            params: RecommendationStatusParameters(pRecommendationID: id, pStatus: status)
        ).execute().value
    }

    func compatibility(with friendID: UUID) async throws -> FriendCompatibility {
        let rows: [FriendCompatibility] = try await client.rpc(
            "friend_compatibility",
            params: ["p_friend_id": friendID]
        ).execute().value
        guard let compatibility = rows.first else {
            throw SocialDiscoveryServiceError.compatibilityUnavailable
        }
        return compatibility
    }

    func reactions(for visitID: UUID) async throws -> [SipReactionRecord] {
        try await client
            .from("visit_reactions")
            .select("visit_id,user_id,reaction")
            .eq("visit_id", value: visitID.uuidString)
            .execute()
            .value
    }

    func toggleReaction(_ reaction: SipReaction, visitID: UUID) async throws -> SipReaction? {
        let response: String? = try await client.rpc(
            "toggle_visit_reaction",
            params: ToggleReactionParameters(pVisitID: visitID, pReaction: reaction.rawValue)
        ).execute().value
        return response.flatMap(SipReaction.init(rawValue:))
    }
}

enum SocialDiscoveryServiceError: Error {
    case compatibilityUnavailable
    case invalidRecipePublicationContract
    case invalidRecipeAdaptationName
    case recipeProjectionUnavailable
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

private struct FriendCafeDiscoveryParameters: Encodable {
    let pLatitude: Double?
    let pLongitude: Double?
    let pRadiusKM: Double
    let pLimit: Int
    let pAfterScore: Double?
    let pAfterID: UUID?

    enum CodingKeys: String, CodingKey {
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

private struct CreateCafeListParameters: Encodable {
    let pTitle: String
    let pDescription: String?
    let pVisibility: String
    enum CodingKeys: String, CodingKey {
        case pTitle = "p_title"
        case pDescription = "p_description"
        case pVisibility = "p_visibility"
    }
}

private struct AddCafeListItemParameters: Encodable {
    let pListID: UUID
    let pCafeID: UUID
    let pNote: String?
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pCafeID = "p_cafe_id"
        case pNote = "p_note"
    }
}

private struct InviteCafeListMemberParameters: Encodable {
    let pListID: UUID
    let pUserID: UUID
    let pRole: String
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pUserID = "p_user_id"
        case pRole = "p_role"
    }
}

private struct MoveCafeListItemParameters: Encodable {
    let pItemID: UUID
    let pPosition: Int
    enum CodingKeys: String, CodingKey {
        case pItemID = "p_item_id"
        case pPosition = "p_position"
    }
}

private struct ListInvitationResponseParameters: Encodable {
    let pListID: UUID
    let pAccept: Bool
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pAccept = "p_accept"
    }
}

private struct TrustedRecommendationParameters: Encodable {
    let pRecipientID: UUID
    let pTargetKind: String
    let pTargetID: UUID
    let pNote: String?
    enum CodingKeys: String, CodingKey {
        case pRecipientID = "p_recipient_id"
        case pTargetKind = "p_target_kind"
        case pTargetID = "p_target_id"
        case pNote = "p_note"
    }
}

private struct RecommendationStatusParameters: Encodable {
    let pRecommendationID: UUID
    let pStatus: String
    enum CodingKeys: String, CodingKey {
        case pRecommendationID = "p_recommendation_id"
        case pStatus = "p_status"
    }
}

private struct ToggleReactionParameters: Encodable {
    let pVisitID: UUID
    let pReaction: String
    enum CodingKeys: String, CodingKey {
        case pVisitID = "p_visit_id"
        case pReaction = "p_reaction"
    }
}

private struct VisitTagParameters: Encodable {
    let pVisitID: UUID
    let pTaggedUserIDs: [UUID]
    enum CodingKeys: String, CodingKey {
        case pVisitID = "p_visit_id"
        case pTaggedUserIDs = "p_tagged_user_ids"
    }
}

private struct SharedMemoryInvitationParameters: Encodable {
    let pVisitID: UUID
    let pInviteeIDs: [UUID]
    enum CodingKeys: String, CodingKey {
        case pVisitID = "p_visit_id"
        case pInviteeIDs = "p_invitee_ids"
    }
}

private struct RecipeProjectionReference: Decodable {
    let recipeVersionID: UUID
    enum CodingKeys: String, CodingKey {
        case recipeVersionID = "recipe_version_id"
    }
}

private struct SaveRecipeAdaptationParameters: Encodable {
    let pSourceRecipeVersionID: UUID
    let pName: String
    let pVersionLabel: String
    enum CodingKeys: String, CodingKey {
        case pSourceRecipeVersionID = "p_source_recipe_version_id"
        case pName = "p_name"
        case pVersionLabel = "p_version_label"
    }
}

private struct RecipeSourceRightsParameters: Encodable {
    let pRecipeVersionID: UUID
    let pSourceKind: String
    let pRedistributionAllowed: Bool
    let pSourceRecipeVersionID: UUID?
    enum CodingKeys: String, CodingKey {
        case pRecipeVersionID = "p_recipe_version_id"
        case pSourceKind = "p_source_kind"
        case pRedistributionAllowed = "p_redistribution_allowed"
        case pSourceRecipeVersionID = "p_source_recipe_version_id"
    }
}

private struct RecipeVisibilityParameters: Encodable {
    let pRecipeVersionID: UUID
    let pVisibility: String
    let pAcknowledgesPublicReuse: Bool
    enum CodingKeys: String, CodingKey {
        case pRecipeVersionID = "p_recipe_version_id"
        case pVisibility = "p_visibility"
        case pAcknowledgesPublicReuse = "p_acknowledges_public_reuse"
    }
}
