import Combine
import Foundation
import Supabase

enum ReflectionReminderKind: String, Decodable {
    case onThisDay = "on_this_day"
    case weekly = "weekly_reflection"
}

struct ReflectionReminderRecord: Decodable, Identifiable, Equatable {
    let id: UUID
    let kind: ReflectionReminderKind
    let scheduledAt: String
    let deliveredAt: String
    let timezoneName: String
    let targetVisitID: UUID?

    enum CodingKeys: String, CodingKey {
        case id = "occurrence_id"
        case kind = "reminder_kind"
        case scheduledAt = "scheduled_at"
        case deliveredAt = "delivered_at"
        case timezoneName = "timezone_name"
        case targetVisitID = "target_visit_id"
    }

    var scheduledDate: Date? { Self.parseDate(scheduledAt) }
    var deliveredDate: Date? { Self.parseDate(deliveredAt) }
    var weekStart: Date? { scheduledDate?.addingTimeInterval(-7 * 24 * 60 * 60) }
    var destination: ReflectionReminderDestination? {
        switch kind {
        case .weekly: .journal
        case .onThisDay: targetVisitID.map(ReflectionReminderDestination.memory)
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

final class ReflectionReminderService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func delivered(
        accountID: UUID,
        limit: Int = 30,
        occurrenceID: UUID? = nil
    ) async throws -> [ReflectionReminderRecord] {
        guard client.auth.currentUser?.id == accountID else {
            throw ActivityServiceError.accountScopeChanged
        }
        let rows: [ReflectionReminderRecord] = try await client.rpc(
            "list_reflection_reminders_v1",
            params: ReflectionReminderListParameters(
                pLimit: min(max(limit, 1), 50),
                pOccurrenceID: occurrenceID
            )
        ).execute().value
        guard client.auth.currentUser?.id == accountID else {
            throw ActivityServiceError.accountScopeChanged
        }
        return rows
    }
}

private struct ReflectionReminderListParameters: Encodable {
    let pLimit: Int
    let pOccurrenceID: UUID?

    enum CodingKeys: String, CodingKey {
        case pLimit = "p_limit"
        case pOccurrenceID = "p_occurrence_id"
    }
}

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
