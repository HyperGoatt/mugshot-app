import Foundation

struct CapturePreferences: Codable, Equatable {
    var usualDrinkFamilies: [String]
    var cafeHomeHabit: String?
    var discoveryIntents: [String]
    var setupCompletedAt: Date?

    static let empty = CapturePreferences(
        usualDrinkFamilies: [],
        cafeHomeHabit: nil,
        discoveryIntents: [],
        setupCompletedAt: nil
    )
}

struct SupabaseCapturePreferences: Codable, Equatable {
    let userId: UUID
    let usualDrinkFamilies: [String]
    let cafeHomeHabit: String?
    let discoveryIntents: [String]
    let setupCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case usualDrinkFamilies = "usual_drink_families"
        case cafeHomeHabit = "cafe_home_habit"
        case discoveryIntents = "discovery_intents"
        case setupCompletedAt = "setup_completed_at"
    }

    var local: CapturePreferences {
        CapturePreferences(
            usualDrinkFamilies: usualDrinkFamilies,
            cafeHomeHabit: cafeHomeHabit,
            discoveryIntents: discoveryIntents,
            setupCompletedAt: setupCompletedAt
        )
    }
}

struct CapturePreferencesUpsert: Encodable {
    let userId: UUID
    let usualDrinkFamilies: [String]
    let cafeHomeHabit: String?
    let discoveryIntents: [String]
    let setupCompletedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case usualDrinkFamilies = "usual_drink_families"
        case cafeHomeHabit = "cafe_home_habit"
        case discoveryIntents = "discovery_intents"
        case setupCompletedAt = "setup_completed_at"
        case updatedAt = "updated_at"
    }
}
