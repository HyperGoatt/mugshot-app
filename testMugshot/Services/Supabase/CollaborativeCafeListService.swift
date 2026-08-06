import Foundation
import Supabase

enum CollaborativeCafeListServiceError: Error, Equatable {
    case accountScopeMismatch
}

struct CollaborativeCafeListAccountScope: Equatable {
    let accountID: UUID

    func perform<Value>(
        currentAccountID: () -> UUID?,
        operation: () async throws -> Value
    ) async throws -> Value {
        try validate(currentAccountID())
        do {
            let value = try await operation()
            try validate(currentAccountID())
            return value
        } catch {
            // Prefer the identity failure when the session changed while the
            // request was in flight, even if the transport also failed.
            try validate(currentAccountID())
            throw error
        }
    }

    private func validate(_ currentAccountID: UUID?) throws {
        guard currentAccountID == accountID else {
            throw CollaborativeCafeListServiceError.accountScopeMismatch
        }
    }
}

final class CollaborativeCafeListService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func lists(accountID: UUID) async throws -> [CollaborativeCafeList] {
        try await scoped(to: accountID) {
            try await client
                .rpc("list_cafe_lists_v2")
                .execute()
                .value
        }
    }

    func list(id: UUID, accountID: UUID) async throws -> CollaborativeCafeList {
        try await scoped(to: accountID) {
            try await client.rpc(
                "get_cafe_list_v2",
                params: ListIDParameters(pListID: id)
            ).execute().value
        }
    }

    func create(
        title: String,
        description: String?,
        visibility: CafeListVisibility,
        accountID: UUID
    ) async throws -> CollaborativeCafeList {
        try await scoped(to: accountID) {
            let created: CollaborativeCafeList = try await client.rpc(
                "create_cafe_list_v2",
                params: CreateParameters(
                    pTitle: title,
                    pDescription: description,
                    pVisibility: visibility == .public
                        ? CafeListVisibility.private.rawValue
                        : visibility.rawValue
                )
            ).execute().value
            guard visibility == .public else { return created }
            return try await PublicCafeListService(client: client).setPublication(
                listID: created.id,
                isPublic: true
            )
        }
    }

    func update(
        id: UUID,
        title: String,
        description: String?,
        visibility: CafeListVisibility,
        accountID: UUID
    ) async throws -> CollaborativeCafeList {
        try await scoped(to: accountID) {
            let updated: CollaborativeCafeList = try await client.rpc(
                "update_cafe_list_v2",
                params: UpdateParameters(
                    pListID: id,
                    pTitle: title,
                    pDescription: description,
                    pVisibility: visibility == .public
                        ? CafeListVisibility.private.rawValue
                        : visibility.rawValue
                )
            ).execute().value
            return try await PublicCafeListService(client: client).setPublication(
                listID: updated.id,
                isPublic: visibility == .public
            )
        }
    }

    func invite(
        userID: UUID,
        to listID: UUID,
        role: String,
        accountID: UUID
    ) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "invite_cafe_list_member",
                params: MemberRoleParameters(pListID: listID, pUserID: userID, pRole: role)
            ).execute()
        }
    }

    func respond(to listID: UUID, accept: Bool, accountID: UUID) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "respond_cafe_list_invitation_v2",
                params: InvitationResponseParameters(
                    pListID: listID,
                    pResponse: accept ? "accept" : "decline"
                )
            ).execute()
        }
    }

    func cancelInvitation(
        listID: UUID,
        userID: UUID,
        accountID: UUID
    ) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "cancel_cafe_list_invitation_v2",
                params: MemberParameters(pListID: listID, pUserID: userID)
            ).execute()
        }
    }

    func setRole(
        listID: UUID,
        userID: UUID,
        role: String,
        accountID: UUID
    ) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "set_cafe_list_member_role_v2",
                params: MemberRoleParameters(pListID: listID, pUserID: userID, pRole: role)
            ).execute()
        }
    }

    func removeMember(
        listID: UUID,
        userID: UUID,
        accountID: UUID
    ) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "remove_cafe_list_member_v2",
                params: MemberParameters(pListID: listID, pUserID: userID)
            ).execute()
        }
    }

    func leave(listID: UUID, accountID: UUID) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "leave_cafe_list_v2",
                params: ListIDParameters(pListID: listID)
            ).execute()
        }
    }

    func transfer(
        listID: UUID,
        to newOwnerID: UUID,
        accountID: UUID
    ) async throws -> CollaborativeCafeList {
        try await scoped(to: accountID) {
            try await client.rpc(
                "transfer_cafe_list_ownership_v2",
                params: TransferParameters(pListID: listID, pNewOwnerID: newOwnerID)
            ).execute().value
        }
    }

    func delete(listID: UUID, accountID: UUID) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "delete_cafe_list_v2",
                params: ListIDParameters(pListID: listID)
            ).execute()
        }
    }

    func add(
        cafeID: UUID,
        to listID: UUID,
        note: String? = nil,
        accountID: UUID
    ) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "add_cafe_list_item_v2",
                params: AddItemParameters(pListID: listID, pCafeID: cafeID, pNote: note)
            ).execute()
        }
    }

    func remove(itemID: UUID, accountID: UUID) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "remove_cafe_list_item_v2",
                params: ItemIDParameters(pItemID: itemID)
            ).execute()
        }
    }

    func move(itemID: UUID, to position: Int, accountID: UUID) async throws {
        try await scoped(to: accountID) {
            _ = try await client.rpc(
                "move_cafe_list_item_v2",
                params: MoveItemParameters(pItemID: itemID, pPosition: position)
            ).execute()
        }
    }

    private func scoped<Value>(
        to accountID: UUID,
        operation: () async throws -> Value
    ) async throws -> Value {
        try await CollaborativeCafeListAccountScope(accountID: accountID).perform(
            currentAccountID: { client.auth.currentUser?.id },
            operation: operation
        )
    }
}

private struct ListIDParameters: Encodable {
    let pListID: UUID
    enum CodingKeys: String, CodingKey { case pListID = "p_list_id" }
}

private struct CreateParameters: Encodable {
    let pTitle: String
    let pDescription: String?
    let pVisibility: String
    enum CodingKeys: String, CodingKey {
        case pTitle = "p_title"
        case pDescription = "p_description"
        case pVisibility = "p_visibility"
    }
}

private struct UpdateParameters: Encodable {
    let pListID: UUID
    let pTitle: String
    let pDescription: String?
    let pVisibility: String
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pTitle = "p_title"
        case pDescription = "p_description"
        case pVisibility = "p_visibility"
    }
}

private struct InvitationResponseParameters: Encodable {
    let pListID: UUID
    let pResponse: String
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pResponse = "p_response"
    }
}

private struct MemberParameters: Encodable {
    let pListID: UUID
    let pUserID: UUID
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pUserID = "p_user_id"
    }
}

private struct MemberRoleParameters: Encodable {
    let pListID: UUID
    let pUserID: UUID
    let pRole: String
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pUserID = "p_user_id"
        case pRole = "p_role"
    }
}

private struct TransferParameters: Encodable {
    let pListID: UUID
    let pNewOwnerID: UUID
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pNewOwnerID = "p_new_owner_id"
    }
}

private struct AddItemParameters: Encodable {
    let pListID: UUID
    let pCafeID: UUID
    let pNote: String?
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pCafeID = "p_cafe_id"
        case pNote = "p_note"
    }
}

private struct ItemIDParameters: Encodable {
    let pItemID: UUID
    enum CodingKeys: String, CodingKey { case pItemID = "p_item_id" }
}

private struct MoveItemParameters: Encodable {
    let pItemID: UUID
    let pPosition: Int
    enum CodingKeys: String, CodingKey {
        case pItemID = "p_item_id"
        case pPosition = "p_position"
    }
}
