import Foundation
import Supabase

final class ReflectionPreferencesService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetch() async throws -> UserReflectionPreferences {
        try await client.rpc("get_reflection_preferences").execute().value
    }

    func save(_ preferences: UserReflectionPreferences) async throws -> UserReflectionPreferences {
        try await client.rpc(
            "set_reflection_preferences",
            params: ReflectionPreferenceParameters(preferences: preferences)
        ).execute().value
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
