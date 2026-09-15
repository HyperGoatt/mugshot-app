import Foundation
import Supabase

struct HomeRecipeWorkspaceService {
    let client: SupabaseClient

    func attachRecipes(_ attachments: [HomeRecipePostAttachment], visitID: UUID, ownerID: UUID) async throws {
        try await client.rpc("set_home_post_recipes_v1", params: HomeRecipeAttachmentRequest(
            pVisitID: visitID, pOwnerID: ownerID, pAttachments: attachments)).execute()
    }

    func content(versionID: UUID) async throws -> HomeRecipeContent? {
        try await client.rpc("get_home_recipe_content_v1", params: ["p_version_id": versionID]).execute().value
    }
    func postRecipes(visitID: UUID) async throws -> [HomeSavedRecipeReference] {
        try await client.rpc("get_home_post_recipes_v1", params: ["p_visit_id": visitID]).execute().value
    }

    func fetch(ownerID: UUID) async throws -> HomeRecipeWorkspace {
        let response: HomeWorkspaceResponse = try await client.rpc("get_home_workspace_v1", params: ["p_owner_id": ownerID]).execute().value
        var result = response.document ?? HomeRecipeWorkspace()
        result.remoteRevision = response.revision
        result.pendingOperationID = nil
        return result
    }
    func synchronize(_ workspace: HomeRecipeWorkspace, ownerID: UUID) async throws -> HomeRecipeWorkspace {
        guard let operationID = workspace.pendingOperationID else { return try await fetch(ownerID: ownerID) }
        let response: HomeWorkspaceResponse = try await client.rpc("save_home_workspace_v1", params:
            HomeWorkspaceRequest(pExpectedRevision: workspace.remoteRevision, pOperationID: operationID, pDocument: workspace, pOwnerID: ownerID))
            .execute().value
        var saved = response.document ?? workspace
        saved.remoteRevision = response.revision
        saved.pendingOperationID = nil
        return saved
    }
}

private struct HomeRecipeAttachmentRequest: Encodable {
    let pVisitID: UUID
    let pOwnerID: UUID
    let pAttachments: [HomeRecipePostAttachment]
    enum CodingKeys: String, CodingKey {
        case pVisitID = "p_visit_id", pOwnerID = "p_owner_id", pAttachments = "p_attachments"
    }
}

private struct HomeWorkspaceRequest: Encodable {
    let pExpectedRevision: Int
    let pOperationID: UUID
    let pDocument: HomeRecipeWorkspace
    let pOwnerID: UUID
    enum CodingKeys: String, CodingKey {
        case pExpectedRevision = "p_expected_revision"
        case pOperationID = "p_operation_id"
        case pDocument = "p_document"
        case pOwnerID = "p_owner_id"
    }
}
private struct HomeWorkspaceResponse: Decodable {
    let revision: Int
    let document: HomeRecipeWorkspace?
}
