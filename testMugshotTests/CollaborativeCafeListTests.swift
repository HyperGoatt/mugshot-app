import Foundation
import Testing
@testable import testMugshot

struct CollaborativeCafeListTests {
    @Test func summaryProjectionDecodesWithoutDetailArrays() throws {
        let listID = UUID()
        let ownerID = UUID()
        let json = """
        {
          "id": "\(listID.uuidString)",
          "title": "Queens coffee crawl",
          "description": "Saturday route",
          "visibility": "invited",
          "system_kind": null,
          "created_at": "2026-07-21T12:00:00Z",
          "updated_at": "2026-07-21T13:00:00Z",
          "owner": {
            "identity_state": "visible",
            "user_id": "\(ownerID.uuidString)",
            "display_name": "Joe",
            "username": "joe",
            "avatar_url": null
          },
          "access_kind": "member",
          "current_role": "editor",
          "invited_role": null,
          "invitation_status": "accepted",
          "inviter": null,
          "can_view_items": true,
          "can_edit_items": true,
          "can_manage": false,
          "can_leave": true,
          "can_delete": false,
          "can_transfer": false,
          "social_actions_available": true,
          "cafe_count": 3,
          "collaborator_count": 2,
          "pending_count": 0,
          "preview_photo_url": null,
          "preview_address": "Astoria"
        }
        """

        let list = try JSONDecoder().decode(
            CollaborativeCafeList.self,
            from: Data(json.utf8)
        )

        #expect(list.id == listID)
        #expect(list.roleTitle == "Editor")
        #expect(list.canEditItems)
        #expect(list.canLeave)
        #expect(list.resolvedItems.isEmpty)
        #expect(list.resolvedMembers.isEmpty)
    }

    @Test func pendingInvitationCopyNeverClaimsCafeContentAccess() throws {
        let list = try decodeList(
            accessKind: "pending_invitation",
            currentRole: "viewer",
            invitedRole: "editor",
            canViewItems: false,
            itemsJSON: "[]",
            membersJSON: "[]"
        )

        #expect(list.accessKind == .pendingInvitation)
        #expect(list.roleTitle == "Invited as editor")
        #expect(!list.canViewItems)
        #expect(list.resolvedItems.isEmpty)
    }

    @Test func blockedContributorKeepsCafeWhileIdentityStaysMasked() throws {
        let listID = UUID()
        let cafeID = UUID()
        let itemID = UUID()
        let items = """
        [{
          "id": "\(itemID.uuidString)",
          "list_id": "\(listID.uuidString)",
          "cafe_id": "\(cafeID.uuidString)",
          "position": 0,
          "note": "Try the cardamom latte",
          "created_at": "2026-07-21T12:30:00Z",
          "cafe_name": "Little Flower Cafe",
          "cafe_address": "25-35 36th Ave",
          "cafe_city": "Queens, NY",
          "latitude": 40.756,
          "longitude": -73.932,
          "apple_place_id": null,
          "website_url": null,
          "photo_url": null,
          "is_favorite": true,
          "want_to_try": false,
          "saved_state": "favorite",
          "contributor": { "identity_state": "hidden" }
        }]
        """
        let list = try decodeList(
            id: listID,
            accessKind: "member",
            currentRole: "editor",
            invitedRole: nil,
            canViewItems: true,
            itemsJSON: items,
            membersJSON: "[]"
        )

        let item = try #require(list.resolvedItems.first)
        #expect(item.cafeID == cafeID)
        #expect(item.cafeName == "Little Flower Cafe")
        #expect(item.contributor.identityState == .hidden)
        #expect(item.contributor.userID == nil)
        #expect(item.contributor.attributionName == "a collaborator")
        #expect(item.coordinate?.latitude == 40.756)
        #expect(item.localCafe.isFavorite)
    }

    @Test func departedAndHiddenPeopleDoNotInventProfileIdentifiers() throws {
        let hidden = try JSONDecoder().decode(
            CafeListPerson.self,
            from: Data(#"{"identity_state":"hidden"}"#.utf8)
        )
        let departed = try JSONDecoder().decode(
            CafeListPerson.self,
            from: Data(#"{"identity_state":"departed"}"#.utf8)
        )

        #expect(hidden.userID == nil)
        #expect(hidden.username == nil)
        #expect(hidden.attributionName == "a collaborator")
        #expect(departed.userID == nil)
        #expect(departed.attributionName == "a former member")
    }

    @Test func staleAccountResponseCannotApplyAfterAccountSwitch() {
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let firstRequestID = UUID()
        let secondRequestID = UUID()
        let firstScope = CollaborativeCafeListLoadScope(
            accountID: firstAccountID,
            requestID: firstRequestID
        )

        #expect(firstScope.canApply(
            currentAccountID: firstAccountID,
            activeRequestID: firstRequestID
        ))
        #expect(!firstScope.canApply(
            currentAccountID: secondAccountID,
            activeRequestID: firstRequestID
        ))
        #expect(!firstScope.canApply(
            currentAccountID: firstAccountID,
            activeRequestID: secondRequestID
        ))
    }

    @Test func accountScopeRejectsBeforeStartingAnRPC() async {
        let expectedAccountID = UUID()
        var didRunOperation = false
        let scope = CollaborativeCafeListAccountScope(accountID: expectedAccountID)

        do {
            _ = try await scope.perform(
                currentAccountID: { UUID() },
                operation: {
                    didRunOperation = true
                    return true
                }
            )
            Issue.record("Expected the account boundary to reject the RPC.")
        } catch {
            #expect(error as? CollaborativeCafeListServiceError == .accountScopeMismatch)
        }

        #expect(!didRunOperation)
    }

    @Test func accountScopeRejectsAResponseAfterTheSessionChanges() async {
        let expectedAccountID = UUID()
        let replacementAccountID = UUID()
        var currentAccountID: UUID? = expectedAccountID
        let scope = CollaborativeCafeListAccountScope(accountID: expectedAccountID)

        do {
            _ = try await scope.perform(
                currentAccountID: { currentAccountID },
                operation: {
                    currentAccountID = replacementAccountID
                    return true
                }
            )
            Issue.record("Expected the stale RPC response to be rejected.")
        } catch {
            #expect(error as? CollaborativeCafeListServiceError == .accountScopeMismatch)
        }
    }

    @Test func accountScopeWinsOverAnRPCFailureAfterTheSessionChanges() async {
        let expectedAccountID = UUID()
        let replacementAccountID = UUID()
        var currentAccountID: UUID? = expectedAccountID
        let scope = CollaborativeCafeListAccountScope(accountID: expectedAccountID)

        do {
            _ = try await scope.perform(
                currentAccountID: { currentAccountID },
                operation: { () async throws -> Bool in
                    currentAccountID = replacementAccountID
                    throw FixtureError.transport
                }
            )
            Issue.record("Expected the account boundary to replace the transport failure.")
        } catch {
            #expect(error as? CollaborativeCafeListServiceError == .accountScopeMismatch)
        }
    }

    private func decodeList(
        id: UUID = UUID(),
        accessKind: String,
        currentRole: String,
        invitedRole: String?,
        canViewItems: Bool,
        itemsJSON: String,
        membersJSON: String
    ) throws -> CollaborativeCafeList {
        let ownerID = UUID()
        let invitedRoleJSON = invitedRole.map { "\"\($0)\"" } ?? "null"
        let json = """
        {
          "id": "\(id.uuidString)",
          "title": "Alpha list",
          "description": null,
          "visibility": "invited",
          "system_kind": null,
          "created_at": "2026-07-21T12:00:00Z",
          "updated_at": "2026-07-21T13:00:00Z",
          "owner": {
            "identity_state": "visible",
            "user_id": "\(ownerID.uuidString)",
            "display_name": "Amanda",
            "username": "amanda",
            "avatar_url": null
          },
          "access_kind": "\(accessKind)",
          "current_role": "\(currentRole)",
          "invited_role": \(invitedRoleJSON),
          "invitation_status": \(accessKind == "pending_invitation" ? "\"pending\"" : "\"accepted\""),
          "inviter": null,
          "can_view_items": \(canViewItems),
          "can_edit_items": \(currentRole == "editor"),
          "can_manage": false,
          "can_leave": \(accessKind == "member"),
          "can_delete": false,
          "can_transfer": false,
          "social_actions_available": true,
          "cafe_count": 1,
          "collaborator_count": 1,
          "pending_count": 0,
          "preview_photo_url": null,
          "preview_address": null,
          "items": \(itemsJSON),
          "members": \(membersJSON)
        }
        """
        return try JSONDecoder().decode(
            CollaborativeCafeList.self,
            from: Data(json.utf8)
        )
    }

    private enum FixtureError: Error {
        case transport
    }
}
