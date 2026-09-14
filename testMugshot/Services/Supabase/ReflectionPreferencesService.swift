import Foundation
import Supabase

final class ReflectionPreferencesService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetch() async throws -> UserReflectionPreferences {
        do {
            return try await client.rpc("get_reflection_preferences_v2").execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            return try await client.rpc("get_reflection_preferences").execute().value
        }
    }

    func save(
        _ preferences: UserReflectionPreferences,
        timezoneName: String = TimeZone.current.identifier
    ) async throws -> UserReflectionPreferences {
        do {
            return try await client.rpc(
                "set_reflection_preferences_v2",
                params: ReflectionPreferenceV2Parameters(
                    preferences: preferences,
                    timezoneName: timezoneName
                )
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            return try await client.rpc(
                "set_reflection_preferences",
                params: ReflectionPreferenceParameters(preferences: preferences)
            ).execute().value
        }
    }

    @discardableResult
    func refreshDeviceCapability(
        installationID: UUID,
        timezoneName: String = TimeZone.current.identifier
    ) async throws -> Bool {
        try await client.rpc(
            "set_reflection_device_capability_v1",
            params: ReflectionDeviceCapabilityParameters(
                deviceID: installationID,
                timezoneName: timezoneName,
                supportsRoutes: true
            )
        ).execute().value
    }
}

private struct ReflectionPreferenceV2Parameters: Encodable {
    let monthlyRecaps: Bool
    let yearlyRecaps: Bool
    let onThisSipReminders: Bool
    let reflectionReminders: Bool
    let timezoneName: String
    let deliveryActivated = true
    let clientCapabilityVersion = 1

    init(preferences: UserReflectionPreferences, timezoneName: String) {
        monthlyRecaps = preferences.monthlyRecaps
        yearlyRecaps = preferences.yearlyRecaps
        onThisSipReminders = preferences.onThisSipReminders
        reflectionReminders = preferences.reflectionReminders
        self.timezoneName = timezoneName
    }

    enum CodingKeys: String, CodingKey {
        case monthlyRecaps = "p_monthly_recaps"
        case yearlyRecaps = "p_yearly_recaps"
        case onThisSipReminders = "p_on_this_sip_reminders"
        case reflectionReminders = "p_reflection_reminders"
        case timezoneName = "p_timezone_name"
        case deliveryActivated = "p_delivery_activated"
        case clientCapabilityVersion = "p_client_capability_version"
    }
}

private struct ReflectionDeviceCapabilityParameters: Encodable {
    let deviceID: UUID
    let timezoneName: String
    let supportsRoutes: Bool

    enum CodingKeys: String, CodingKey {
        case deviceID = "p_device_id"
        case timezoneName = "p_timezone_name"
        case supportsRoutes = "p_supports_routes"
    }
}

private struct ReflectionPreferenceParameters: Encodable {
    let monthlyRecaps: Bool
    let yearlyRecaps: Bool
    let onThisSipReminders: Bool
    let reflectionReminders: Bool

    init(preferences: UserReflectionPreferences) {
        monthlyRecaps = preferences.monthlyRecaps
        yearlyRecaps = preferences.yearlyRecaps
        onThisSipReminders = preferences.onThisSipReminders
        reflectionReminders = preferences.reflectionReminders
    }

    enum CodingKeys: String, CodingKey {
        case monthlyRecaps = "p_monthly_recaps"
        case yearlyRecaps = "p_yearly_recaps"
        case onThisSipReminders = "p_on_this_sip_reminders"
        case reflectionReminders = "p_reflection_reminders"
    }
}
