import Foundation
import Supabase

@MainActor
protocol MugsyReminderServicing {
    func fetch() async throws -> MugsyReminderPreferences
    func save(_ preferences: MugsyReminderPreferences, requestID: UUID) async throws -> MugsyReminderPreferences
    func record(_ signal: MugsyCompletedMemorySignal) async throws
    func withdraw(memoryID: UUID) async throws
    func capability(deviceID: UUID) async throws
    func activity(deviceID: UUID, active: Bool, composing: Bool) async throws
    func viewed(weekEnd: Date) async throws
    func nearbyPermit(deviceID: UUID, requestID: UUID) async throws -> MugsyNearbyPermit
    func authorize(_ intent: MugsyNotificationIntent) async throws -> Bool
    func opened(occurrenceID: UUID) async throws
    func baseline(ready: Bool) async throws
}

@MainActor
final class MugsyReminderService: MugsyReminderServicing {
    private let client: SupabaseClient
    private let accountID: UUID

    init(client: SupabaseClient, accountID: UUID) { self.client = client; self.accountID = accountID }

    private func verify() throws {
        guard client.auth.currentUser?.id == accountID else { throw CancellationError() }
    }

    func fetch() async throws -> MugsyReminderPreferences {
        try verify()
        let value: MugsyReminderPreferences = try await client.rpc("get_mugsy_preferences_v1").setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
        return value
    }

    func save(_ preferences: MugsyReminderPreferences, requestID: UUID) async throws -> MugsyReminderPreferences {
        try verify()
        let p = preferences
        let params = PreferenceParameters(p_mugsy_enabled: p.mugsyEnabled, p_pace: p.pace.rawValue,
            p_preferred_minute: p.preferredMinute, p_window_start_minute: p.windowStartMinute,
            p_window_end_minute: p.windowEndMinute, p_timezone_name: p.timezoneName ?? TimeZone.current.identifier,
            p_paused_until: p.pausedUntil, p_paused_indefinitely: p.pausedIndefinitely,
            p_expected_revision: p.revision, p_request_id: requestID)
        let value: MugsyReminderPreferences = try await client.rpc("set_mugsy_preferences_v1", params: params).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
        return value
    }

    func record(_ signal: MugsyCompletedMemorySignal) async throws {
        try verify()
        guard signal.accountID == accountID else { throw CancellationError() }
        let _: Bool = try await client.rpc("record_mugsy_memory_v1", params: MemoryParameters(
            p_memory_id: signal.memoryID, p_origin: signal.origin.rawValue,
            p_completed_at: signal.completedAt, p_linked_visit_id: signal.linkedVisitID)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
    }

    func withdraw(memoryID: UUID) async throws {
        try verify()
        let _: Bool = try await client.rpc("withdraw_mugsy_memory_v1",
            params: WithdrawalParameters(p_memory_id: memoryID)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
    }

    func capability(deviceID: UUID) async throws {
        try verify()
        let _: Bool = try await client.rpc("set_mugsy_device_capability_v1", params: CapabilityParameters(
            p_device_id: deviceID, p_timezone_name: TimeZone.current.identifier, p_capability_version: 1)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
    }

    func activity(deviceID: UUID, active: Bool, composing: Bool) async throws {
        try verify()
        let _: Bool = try await client.rpc("record_mugsy_activity_v1", params: ActivityParameters(
            p_device_id: deviceID, p_active: active, p_composing: composing)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
    }

    func viewed(weekEnd: Date) async throws {
        try verify()
        let _: Bool = try await client.rpc("record_mugsy_week_viewed_v1", params: WeekParameters(p_week_end: weekEnd)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
    }

    func nearbyPermit(deviceID: UUID, requestID: UUID) async throws -> MugsyNearbyPermit {
        try verify()
        let permit: MugsyNearbyPermit = try await client.rpc("request_mugsy_nearby_permit_v1",
            params: NearbyParameters(p_device_id: deviceID, p_request_id: requestID)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
        return permit
    }

    func authorize(_ intent: MugsyNotificationIntent) async throws -> Bool {
        try verify()
        guard intent.accountID == accountID, intent.expiresAt > .now else { return false }
        let result: AuthorizedIntent? = try await client.rpc("get_mugsy_notification_intent_v1",
            params: IntentParameters(p_occurrence_id: intent.occurrenceID)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
        guard let result else { return false }
        return result.expiresAt > .now
            && URL(string: result.deepLink).flatMap(MugsyNotificationIntent.Destination.resolve) == intent.destination
    }

    func opened(occurrenceID: UUID) async throws {
        try verify()
        let _: Bool = try await client.rpc("record_mugsy_notification_open_v1",
            params: IntentParameters(p_occurrence_id: occurrenceID)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
    }

    func baseline(ready: Bool) async throws {
        try verify()
        let _: Bool = try await client.rpc("record_mugsy_baseline_v1", params: BaselineParameters(
            p_device_id: NotificationDeviceCoordinator.shared.currentInstallationID, p_ready: ready)).setHeader(name: "x-mugshot-account-id", value: accountID.uuidString.lowercased()).execute().value
        try verify()
    }
}

private struct PreferenceParameters: Encodable {
    let p_mugsy_enabled: Bool
    let p_pace: String
    let p_preferred_minute: Int
    let p_window_start_minute: Int
    let p_window_end_minute: Int
    let p_timezone_name: String
    let p_paused_until: Date?
    let p_paused_indefinitely: Bool
    let p_expected_revision: Int
    let p_request_id: UUID

    enum CodingKeys: String, CodingKey {
        case p_mugsy_enabled, p_pace, p_preferred_minute, p_window_start_minute, p_window_end_minute
        case p_timezone_name, p_paused_until, p_paused_indefinitely, p_expected_revision, p_request_id
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(p_mugsy_enabled, forKey: .p_mugsy_enabled)
        try values.encode(p_pace, forKey: .p_pace)
        try values.encode(p_preferred_minute, forKey: .p_preferred_minute)
        try values.encode(p_window_start_minute, forKey: .p_window_start_minute)
        try values.encode(p_window_end_minute, forKey: .p_window_end_minute)
        try values.encode(p_timezone_name, forKey: .p_timezone_name)
        if let p_paused_until { try values.encode(p_paused_until, forKey: .p_paused_until) }
        else { try values.encodeNil(forKey: .p_paused_until) }
        try values.encode(p_paused_indefinitely, forKey: .p_paused_indefinitely)
        try values.encode(p_expected_revision, forKey: .p_expected_revision)
        try values.encode(p_request_id, forKey: .p_request_id)
    }
}
private struct MemoryParameters: Encodable {
    let p_memory_id: UUID
    let p_origin: String
    let p_completed_at: Date
    let p_linked_visit_id: UUID?
}
private struct WithdrawalParameters: Encodable { let p_memory_id: UUID }
private struct CapabilityParameters: Encodable {
    let p_device_id: UUID
    let p_timezone_name: String
    let p_capability_version: Int
}
private struct ActivityParameters: Encodable {
    let p_device_id: UUID
    let p_active: Bool
    let p_composing: Bool
}
private struct WeekParameters: Encodable { let p_week_end: Date }
private struct NearbyParameters: Encodable { let p_device_id: UUID; let p_request_id: UUID }
private struct IntentParameters: Encodable { let p_occurrence_id: UUID }
private struct BaselineParameters: Encodable { let p_device_id: UUID; let p_ready: Bool }
private struct AuthorizedIntent: Decodable {
    let deepLink: String
    let expiresAt: Date
    enum CodingKeys: String, CodingKey { case deepLink = "deep_link", expiresAt = "expires_at" }
}
