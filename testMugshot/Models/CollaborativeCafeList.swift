import CoreLocation
import Foundation

enum CafeListIdentityState: String, Codable, Equatable {
    case visible
    case hidden
    case departed
}

struct CafeListPerson: Codable, Equatable {
    let identityState: CafeListIdentityState
    let userID: UUID?
    let displayName: String?
    let username: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case identityState = "identity_state"
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
    }

    var visibleName: String {
        switch identityState {
        case .visible:
            return displayName?.remoteTrimmedNonEmpty
                ?? username.map { "@\($0)" }
                ?? "MugShot member"
        case .hidden:
            return "Hidden collaborator"
        case .departed:
            return "Former member"
        }
    }

    var attributionName: String {
        switch identityState {
        case .visible:
            return displayName?.remoteTrimmedNonEmpty
                ?? username.map { "@\($0)" }
                ?? "a collaborator"
        case .hidden:
            return "a collaborator"
        case .departed:
            return "a former member"
        }
    }
}

enum CafeListAccessKind: String, Codable, Equatable {
    case owner
    case member
    case pendingInvitation = "pending_invitation"
    case friendViewer = "friend_viewer"
    case viewer
}

struct CollaborativeCafeListLoadScope: Equatable {
    let accountID: UUID
    let requestID: UUID

    func canApply(
        currentAccountID: UUID,
        activeRequestID: UUID?
    ) -> Bool {
        accountID == currentAccountID && requestID == activeRequestID
    }
}

struct CollaborativeCafeList: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let visibility: CafeListVisibility
    let systemKind: String?
    let createdAt: String
    let updatedAt: String
    let owner: CafeListPerson
    let accessKind: CafeListAccessKind
    let currentRole: String
    let invitedRole: String?
    let invitationStatus: String?
    let inviter: CafeListPerson?
    let canViewItems: Bool
    let canEditItems: Bool
    let canManage: Bool
    let canLeave: Bool
    let canDelete: Bool
    let canTransfer: Bool
    let socialActionsAvailable: Bool
    let cafeCount: Int
    let collaboratorCount: Int
    let pendingCount: Int
    let previewPhotoURL: String?
    let previewAddress: String?
    let items: [CollaborativeCafeListItem]?
    let members: [CollaborativeCafeListMember]?

    enum CodingKeys: String, CodingKey {
        case id, title, description, visibility, owner, inviter, items, members
        case systemKind = "system_kind"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case accessKind = "access_kind"
        case currentRole = "current_role"
        case invitedRole = "invited_role"
        case invitationStatus = "invitation_status"
        case canViewItems = "can_view_items"
        case canEditItems = "can_edit_items"
        case canManage = "can_manage"
        case canLeave = "can_leave"
        case canDelete = "can_delete"
        case canTransfer = "can_transfer"
        case socialActionsAvailable = "social_actions_available"
        case cafeCount = "cafe_count"
        case collaboratorCount = "collaborator_count"
        case pendingCount = "pending_count"
        case previewPhotoURL = "preview_photo_url"
        case previewAddress = "preview_address"
    }

    var resolvedItems: [CollaborativeCafeListItem] { items ?? [] }
    var resolvedMembers: [CollaborativeCafeListMember] { members ?? [] }

    var roleTitle: String {
        switch accessKind {
        case .owner: return "Owner"
        case .pendingInvitation:
            return invitedRole == "editor" ? "Invited as editor" : "Invited as viewer"
        case .friendViewer: return "Visible to friends"
        case .member, .viewer:
            return currentRole == "editor" ? "Editor" : "Viewer"
        }
    }
}

struct CollaborativeCafeListItem: Identifiable, Codable, Equatable {
    let id: UUID
    let listID: UUID
    let cafeID: UUID
    let position: Int
    let note: String?
    let createdAt: String
    let cafeName: String
    let cafeAddress: String?
    let cafeCity: String?
    let latitude: Double?
    let longitude: Double?
    let applePlaceID: String?
    let websiteURL: String?
    let photoURL: String?
    let isFavorite: Bool
    let wantToTry: Bool
    let savedState: String
    let contributor: CafeListPerson

    enum CodingKeys: String, CodingKey {
        case id, position, note, latitude, longitude, contributor
        case listID = "list_id"
        case cafeID = "cafe_id"
        case createdAt = "created_at"
        case cafeName = "cafe_name"
        case cafeAddress = "cafe_address"
        case cafeCity = "cafe_city"
        case applePlaceID = "apple_place_id"
        case websiteURL = "website_url"
        case photoURL = "photo_url"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
        case savedState = "saved_state"
    }

    var displayLocation: String? {
        [cafeAddress, cafeCity]
            .compactMap { $0?.remoteTrimmedNonEmpty }
            .uniqued()
            .joined(separator: " · ")
            .remoteTrimmedNonEmpty
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude,
              (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var localCafe: Cafe {
        Cafe(
            id: cafeID,
            name: cafeName,
            location: coordinate,
            address: cafeAddress?.remoteTrimmedNonEmpty ?? cafeCity?.remoteTrimmedNonEmpty ?? "",
            isFavorite: isFavorite,
            wantToTry: wantToTry,
            mapItemURL: applePlaceID,
            websiteURL: websiteURL,
            remoteCafeId: cafeID
        )
    }
}

struct CollaborativeCafeListMember: Identifiable, Codable, Equatable {
    let role: String
    let invitationStatus: String
    let createdAt: String
    let updatedAt: String
    let acceptedAt: String?
    let respondedAt: String?
    let person: CafeListPerson
    let inviter: CafeListPerson
    let canChangeRole: Bool
    let canRemove: Bool

    enum CodingKeys: String, CodingKey {
        case role, person, inviter
        case invitationStatus = "invitation_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case acceptedAt = "accepted_at"
        case respondedAt = "responded_at"
        case canChangeRole = "can_change_role"
        case canRemove = "can_remove"
    }

    var roleTitle: String { role == "editor" ? "Editor" : "Viewer" }
    var isPending: Bool { invitationStatus == "pending" }
    var isAccepted: Bool { invitationStatus == "accepted" }
    var id: String {
        "\(person.userID?.uuidString ?? person.identityState.rawValue)-\(createdAt)-\(role)"
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        reduce(into: []) { result, value in
            guard !result.contains(value) else { return }
            result.append(value)
        }
    }
}
