import Combine
import Foundation

enum ReflectionReminderDestination: Codable, Equatable {
    case memory(UUID)
    case journal

    static func resolve(_ url: URL) -> Self? {
        guard url.scheme?.lowercased() == "mugshot",
              url.host?.lowercased() == "reflection" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        if components == ["journal"] { return .journal }
        if components.count == 2,
           components[0] == "memory",
           let visitID = UUID(uuidString: components[1]) {
            return .memory(visitID)
        }
        return nil
    }
}

struct PendingReflectionReminderRoute: Codable, Equatable, Identifiable {
    let id: UUID
    let accountID: UUID
    let occurrenceID: UUID
    let destination: ReflectionReminderDestination

    init(
        id: UUID = UUID(),
        accountID: UUID,
        occurrenceID: UUID,
        destination: ReflectionReminderDestination
    ) {
        self.id = id
        self.accountID = accountID
        self.occurrenceID = occurrenceID
        self.destination = destination
    }
}

struct ReflectionPushRouteEnvelope: Equatable {
    let accountID: UUID
    let occurrenceID: UUID
    let destination: ReflectionReminderDestination

    static func resolve(userInfo: [AnyHashable: Any]) -> Self? {
        let rawPayload = userInfo["mugshot_reflection"]
        let payload: [AnyHashable: Any]
        if let typed = rawPayload as? [AnyHashable: Any] {
            payload = typed
        } else if let typed = rawPayload as? [String: Any] {
            payload = Dictionary(uniqueKeysWithValues: typed.map { (AnyHashable($0.key), $0.value) })
        } else {
            return nil
        }
        guard let recipient = payload["recipient_id"] as? String,
              let accountID = UUID(uuidString: recipient),
              let occurrence = payload["occurrence_id"] as? String,
              let occurrenceID = UUID(uuidString: occurrence),
              let deepLink = payload["deep_link"] as? String,
              let url = URL(string: deepLink),
              let destination = ReflectionReminderDestination.resolve(url) else {
            return nil
        }
        return Self(
            accountID: accountID,
            occurrenceID: occurrenceID,
            destination: destination
        )
    }
}

@MainActor
final class ReflectionReminderRouter: ObservableObject {
    static let shared = ReflectionReminderRouter()
    private static let storageKey = "MugshotReflection.pendingRoute.v1"

    @Published private(set) var pendingRoute: PendingReflectionReminderRoute?
    private let defaults: UserDefaults
    private var activeAccountID: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            pendingRoute = try? JSONDecoder().decode(PendingReflectionReminderRoute.self, from: data)
        }
    }

    func activate(accountID: UUID?) {
        activeAccountID = accountID
        guard let accountID, let pendingRoute else { return }
        if pendingRoute.accountID != accountID { clear() }
    }

    func enqueue(_ envelope: ReflectionPushRouteEnvelope) {
        guard activeAccountID == nil || activeAccountID == envelope.accountID else { return }
        let route = PendingReflectionReminderRoute(
            accountID: envelope.accountID,
            occurrenceID: envelope.occurrenceID,
            destination: envelope.destination
        )
        pendingRoute = route
        if let data = try? JSONEncoder().encode(route) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func consume(_ route: PendingReflectionReminderRoute, accountID: UUID) {
        guard pendingRoute?.id == route.id,
              route.accountID == accountID,
              activeAccountID == accountID else { return }
        clear()
    }

    func deactivateForSignedOutSession() {
        activeAccountID = nil
        clear()
    }

    private func clear() {
        pendingRoute = nil
        defaults.removeObject(forKey: Self.storageKey)
    }
}
