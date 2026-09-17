import Foundation

@MainActor
final class FriendInviteRouter: ObservableObject {
    static let shared = FriendInviteRouter()
    private static let storageKey = "MugshotPeople.pendingInvite.v1"
    private static let maximumAge: TimeInterval = 14 * 24 * 60 * 60

    @Published private(set) var pendingRoute: FriendInviteRoute?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let route = try? JSONDecoder().decode(FriendInviteRoute.self, from: data),
           Date().timeIntervalSince(route.createdAt) <= Self.maximumAge {
            pendingRoute = route
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }

    @discardableResult
    func enqueue(url: URL) -> Bool {
        guard let route = FriendInviteRoute.resolve(url) else { return false }
        pendingRoute = route
        persist(route)
        return true
    }

    func consume(_ route: FriendInviteRoute) {
        guard pendingRoute?.id == route.id else { return }
        pendingRoute = nil
        defaults.removeObject(forKey: Self.storageKey)
    }

    func clear() {
        pendingRoute = nil
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist(_ route: FriendInviteRoute) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
