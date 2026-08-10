import Foundation

enum CapturePreferenceGoal: String, CaseIterable, Identifiable, Codable {
    case nearby
    case taste
    case journal
    case friends

    var id: String { rawValue }
}

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

    var onboardingGoal: CapturePreferenceGoal? {
        CapturePreferenceGoal.allCases.first {
            discoveryIntents.contains($0.rawValue)
        }
    }

    func applyingOnboardingGoal(_ goal: CapturePreferenceGoal) -> CapturePreferences {
        var updated = self
        let onboardingIntentIDs = Set(CapturePreferenceGoal.allCases.map(\.rawValue))
        updated.discoveryIntents.removeAll { onboardingIntentIDs.contains($0) }
        updated.discoveryIntents.append(goal.rawValue)
        return updated
    }
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
