import Foundation

enum JournalEntryContext: String, Codable, CaseIterable, Identifiable {
    case cafe = "Cafe"
    case home = "Home"
    case elsewhere = "Elsewhere"
    case recipe = "Recipe"

    var id: String { rawValue }

    var supportsCafeSession: Bool { self == .cafe }

    var systemImage: String {
        switch self {
        case .cafe: return "mappin.and.ellipse"
        case .home: return "house.fill"
        case .elsewhere: return "mappin.and.ellipse"
        case .recipe: return "book.pages.fill"
        }
    }

    var locationFallback: String {
        switch self {
        case .cafe: return "Cafe"
        case .home: return "Home Brew"
        case .elsewhere: return "Elsewhere"
        case .recipe: return "Home Recipe"
        }
    }

    init(backendValue: String?) {
        switch backendValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "home", "home brew": self = .home
        case "elsewhere": self = .elsewhere
        case "recipe": self = .recipe
        default: self = .cafe
        }
    }
}

struct BrewDetails: Codable, Equatable, Sendable {
    var beans: String?
    var doseGrams: Double?
    var yieldGrams: Double?
    var brewTimeSeconds: Int?
    var beanOrigin: String?
    var roastLevel: String?
    var grindSetting: String?
    var waterTemperatureCelsius: Double?
    var waterNotes: String?
    var recipeName: String?
    var recipeVersion: String?
    var recipeIdentityID: UUID?
    var sourceRecipeIdentityID: UUID?
    var sourceRecipeVersion: String?
    var steps: [BrewRecipeStep]?
    var orderNotes: String?
    var tags: [String]?
    var companions: [String]?
    var additions: String?
    var servingVolumeMilliliters: Double?
    var espressoShotCount: Int?
    /// Safe identity snapshot only. Owner IDs, inventory state, OCR text, and
    /// private media paths remain in the owner-only Home library.
    var coffeeBag: CoffeeBagSnapshot?
    var equipmentSnapshots: [EquipmentSnapshot]?
    var homeMethodDetails: HomeMethodDetails?

    static let empty = BrewDetails()

    var hasStructuredData: Bool {
        beans?.remoteTrimmedNonEmpty != nil || doseGrams != nil || yieldGrams != nil || brewTimeSeconds != nil ||
            beanOrigin?.remoteTrimmedNonEmpty != nil || roastLevel?.remoteTrimmedNonEmpty != nil ||
            grindSetting?.remoteTrimmedNonEmpty != nil || waterTemperatureCelsius != nil ||
            waterNotes?.remoteTrimmedNonEmpty != nil ||
            recipeName?.remoteTrimmedNonEmpty != nil || recipeVersion?.remoteTrimmedNonEmpty != nil ||
            recipeIdentityID != nil || sourceRecipeIdentityID != nil ||
            sourceRecipeVersion?.remoteTrimmedNonEmpty != nil || !(steps ?? []).isEmpty ||
            orderNotes?.remoteTrimmedNonEmpty != nil || !(tags ?? []).isEmpty ||
            !(companions ?? []).isEmpty ||
            additions?.remoteTrimmedNonEmpty != nil || servingVolumeMilliliters != nil ||
            espressoShotCount != nil || coffeeBag != nil ||
            !(equipmentSnapshots ?? []).isEmpty || homeMethodDetails?.hasData == true
    }

    var recipeDisplayName: String? {
        guard let name = recipeName?.remoteTrimmedNonEmpty else { return nil }
        guard let version = recipeVersion?.remoteTrimmedNonEmpty else { return name }
        return "\(name) · \(version)"
    }

    var extractionSummary: String? {
        var parts: [String] = []
        if let doseGrams { parts.append(Self.grams(doseGrams, suffix: "in")) }
        if let yieldGrams {
            parts.append(Self.grams(yieldGrams, suffix: "out"))
        } else if let waterGrams = homeMethodDetails?.waterGrams {
            parts.append(Self.grams(waterGrams, suffix: "water"))
        }
        if let brewTimeSeconds { parts.append("\(brewTimeSeconds) sec") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var brewRatio: Double? {
        guard let doseGrams, doseGrams > 0 else { return nil }
        let output = yieldGrams ?? homeMethodDetails?.waterGrams
        guard let output, output > 0 else { return nil }
        return output / doseGrams
    }

    var equipmentDisplayName: String? {
        let names = (equipmentSnapshots ?? []).map(\.displayName)
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    private static func grams(_ value: Double, suffix: String) -> String {
        let formatted = value.rounded() == value
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(formatted)g \(suffix)"
    }
}

struct BrewRecipeStep: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var instruction: String
    var durationSeconds: Int?

    init(
        id: UUID = UUID(),
        instruction: String = "",
        durationSeconds: Int? = nil
    ) {
        self.id = id
        self.instruction = instruction
        self.durationSeconds = durationSeconds
    }
}

struct ResolvedCafeSummary: Decodable, Equatable {
    let cafeID: UUID
    let name: String
    let address: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let identityKey: String?
    let applePlaceID: String?
    let websiteURL: String?
    let averageRating: Double?
    let visibleVisitCount: Int
    let recentCover: String?
    let isFavorite: Bool
    let wantToTry: Bool
    let isVisited: Bool

    enum CodingKeys: String, CodingKey {
        case name, address, city, latitude, longitude
        case cafeID = "cafe_id"
        case identityKey = "identity_key"
        case applePlaceID = "apple_place_id"
        case websiteURL = "website_url"
        case averageRating = "average_rating"
        case visibleVisitCount = "visible_visit_count"
        case recentCover = "recent_cover"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
        case isVisited = "is_visited"
    }

    var remoteCafe: SupabaseCafeSummary {
        SupabaseCafeSummary(
            id: cafeID,
            name: name,
            address: address,
            city: city,
            latitude: latitude,
            longitude: longitude,
            applePlaceId: applePlaceID,
            websiteURL: websiteURL,
            identityKey: identityKey
        )
    }
}
