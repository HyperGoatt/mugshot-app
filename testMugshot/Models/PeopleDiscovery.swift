import Foundation

struct PeopleDiscoveryCapabilities: Decodable, Equatable {
    let contactMatching: Bool
    let invitations: Bool
    let suggestions: Bool
    let firstWeekPrompt: Bool

    static let unavailable = PeopleDiscoveryCapabilities(
        contactMatching: false,
        invitations: false,
        suggestions: false,
        firstWeekPrompt: false
    )

    enum CodingKeys: String, CodingKey {
        case contactMatching = "contact_matching"
        case invitations, suggestions
        case firstWeekPrompt = "first_week_prompt"
    }
}

struct PeopleSuggestion: Identifiable, Decodable, Equatable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let friendshipState: FriendshipState
    let mutualFriendCount: Int
    let reason: String
    let rankingVersion: String

    enum CodingKeys: String, CodingKey {
        case id, username, reason
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case friendshipState = "friendship_state"
        case mutualFriendCount = "mutual_friend_count"
        case rankingVersion = "ranking_version"
    }

    var reasonText: String {
        switch reason {
        case "shared_mugshot": "Shared a Mugshot with you"
        case "shared_list": "On a cafe list with you"
        case "mutual_friends": "\(mutualFriendCount) mutual friend\(mutualFriendCount == 1 ? "" : "s")"
        case "interacted_with_you": "Recently interacted with your Mugshots"
        case "you_interacted": "You recently interacted with their Mugshots"
        default: "Someone you may know"
        }
    }

    var reasonSystemImage: String {
        switch reason {
        case "shared_mugshot": "cup.and.saucer.fill"
        case "shared_list": "list.bullet"
        case "mutual_friends": "person.2.fill"
        case "interacted_with_you": "bubble.left.and.bubble.right.fill"
        case "you_interacted": "heart.fill"
        default: "sparkles"
        }
    }
}

struct PeopleHubPayload: Decodable, Equatable {
    let requests: [SocialConnection]
    let sent: [SocialConnection]
    let friends: [SocialConnection]
    let suggestions: [PeopleSuggestion]
    let partialErrors: [String: String]

    enum CodingKeys: String, CodingKey {
        case requests, sent, friends, suggestions
        case partialErrors = "partial_errors"
    }
}

struct PeopleDiscoveryPreferences: Decodable, Equatable {
    var emailDiscoverable: Bool
    var suggestionsEnabled: Bool
    var mutualExplanationsEnabled: Bool
    let consentVersion: Int?
    let version: Int64
    var hasDiscoveryEmail: Bool

    enum CodingKeys: String, CodingKey {
        case emailDiscoverable = "email_discoverable"
        case suggestionsEnabled = "suggestions_enabled"
        case mutualExplanationsEnabled = "mutual_explanations_enabled"
        case consentVersion = "consent_version"
        case version
        case hasDiscoveryEmail = "has_discovery_email"
    }
}

struct FriendInvite: Identifiable, Decodable, Equatable {
    let id: UUID
    let token: String
    let code: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case id = "invite_id"
        case token, code
        case expiresAt = "expires_at"
    }
}

struct ResolvedFriendInvite: Decodable, Equatable {
    let inviteID: UUID
    let userID: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let friendshipState: FriendshipState
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case inviteID = "invite_id"
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case friendshipState = "friendship_state"
        case expiresAt = "expires_at"
    }
}

struct SelectedContactForDiscovery: Identifiable, Equatable {
    let id: String
    let displayName: String
    let emails: [String]
}

struct SelectedContactInvitation: Identifiable, Equatable {
    let id: String
    let displayName: String
    let phoneNumber: String
}

struct ContactDiscoveryMatch: Identifiable, Decodable, Equatable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let friendshipState: FriendshipState
    let mutualFriendCount: Int

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case friendshipState = "friendship_state"
        case mutualFriendCount = "mutual_friend_count"
    }
}

struct ContactDiscoveryResult: Identifiable, Equatable {
    let id: String
    let contact: SelectedContactForDiscovery
    let matches: [ContactDiscoveryMatch]
}

struct FriendInviteRoute: Codable, Equatable, Identifiable {
    let secret: String
    let createdAt: Date
    var id: String { secret }

    static func resolve(
        _ url: URL,
        publicBaseURL: URL? = MugshotShareConfiguration.load().publicBaseURL
    ) -> Self? {
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme?.lowercased() == "mugshot", let host = url.host {
            parts.insert(host, at: 0)
        }
        guard parts.count == 2, parts[0].lowercased() == "invite",
              url.user == nil, url.password == nil else { return nil }
        let secret = parts[1]
        let tokenIsValid = secret.range(
            of: "^[A-Za-z0-9_-]{40,64}$", options: .regularExpression
        ) != nil
        let codeIsValid = secret.uppercased().range(
            of: "^[A-Z2-9]{4}-?[A-Z2-9]{4}-?[A-Z2-9]{4}$",
            options: .regularExpression
        ) != nil
        guard tokenIsValid || codeIsValid else { return nil }
        if url.scheme?.lowercased() == "mugshot" {
            return FriendInviteRoute(secret: secret, createdAt: Date())
        }
        guard let publicBaseURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == publicBaseURL.host?.lowercased(),
              url.port == publicBaseURL.port else { return nil }
        return FriendInviteRoute(secret: secret, createdAt: Date())
    }
}
