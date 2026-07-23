import Foundation

/// A typed boundary for local state that must never be shared implicitly
/// between a signed-out session and an authenticated account.
enum LocalAccountScope: Equatable, Hashable, Sendable {
    case guest
    case user(UUID)

    static func forUserID(_ userID: UUID?) -> LocalAccountScope {
        userID.map(LocalAccountScope.user) ?? .guest
    }

    var userID: UUID? {
        guard case .user(let userID) = self else { return nil }
        return userID
    }

    var storageComponent: String {
        switch self {
        case .guest:
            return "guest"
        case .user(let userID):
            return "users/\(userID.uuidString.lowercased())"
        }
    }

    var defaultsComponent: String {
        switch self {
        case .guest:
            return "guest"
        case .user(let userID):
            return "user.\(userID.uuidString.lowercased())"
        }
    }
}
