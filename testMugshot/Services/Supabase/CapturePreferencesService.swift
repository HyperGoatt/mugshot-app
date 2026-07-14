import Foundation
import Supabase

final class CapturePreferencesService {
    private let client: SupabaseClient
    private let columns = "user_id, usual_drink_families, cafe_home_habit, discovery_intents, setup_completed_at"

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetch(userId: UUID) async throws -> CapturePreferences? {
        let rows: [SupabaseCapturePreferences] = try await client
            .from("user_capture_preferences")
            .select(columns)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.local
    }

    func save(userId: UUID, preferences: CapturePreferences) async throws -> CapturePreferences {
        let now = Date()
        let payload = CapturePreferencesUpsert(
            userId: userId,
            usualDrinkFamilies: preferences.usualDrinkFamilies.sorted(),
            cafeHomeHabit: preferences.cafeHomeHabit,
            discoveryIntents: preferences.discoveryIntents.sorted(),
            setupCompletedAt: preferences.setupCompletedAt ?? now,
            updatedAt: now
        )
        let row: SupabaseCapturePreferences = try await client
            .from("user_capture_preferences")
            .upsert(payload, onConflict: "user_id")
            .select(columns)
            .single()
            .execute()
            .value
        return row.local
    }
}
