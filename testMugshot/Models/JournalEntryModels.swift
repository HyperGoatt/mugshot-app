import Foundation

enum JournalEntryContext: String, Codable, CaseIterable, Identifiable {
    case cafe = "Cafe"
    case home = "Home"
    case recipe = "Recipe"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cafe: return "mappin.and.ellipse"
        case .home: return "house.fill"
        case .recipe: return "book.pages.fill"
        }
    }

    var locationFallback: String {
        switch self {
        case .cafe: return "Cafe"
        case .home: return "Home Brew"
        case .recipe: return "Home Recipe"
        }
    }

    init(backendValue: String?) {
        switch backendValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "home", "home brew": self = .home
        case "recipe": self = .recipe
        default: self = .cafe
        }
    }
}

struct BrewDetails: Codable, Equatable {
    var doseGrams: Double?
    var yieldGrams: Double?
    var brewTimeSeconds: Int?
    var beanOrigin: String?
    var roastLevel: String?
    var grindSetting: String?
    var waterTemperatureCelsius: Double?
    var recipeName: String?
    var recipeVersion: String?
    var additions: String?

    static let empty = BrewDetails()

    var hasStructuredData: Bool {
        doseGrams != nil || yieldGrams != nil || brewTimeSeconds != nil ||
            beanOrigin?.remoteTrimmedNonEmpty != nil || roastLevel?.remoteTrimmedNonEmpty != nil ||
            grindSetting?.remoteTrimmedNonEmpty != nil || waterTemperatureCelsius != nil ||
            recipeName?.remoteTrimmedNonEmpty != nil || recipeVersion?.remoteTrimmedNonEmpty != nil ||
            additions?.remoteTrimmedNonEmpty != nil
    }

    var recipeDisplayName: String? {
        guard let name = recipeName?.remoteTrimmedNonEmpty else { return nil }
        guard let version = recipeVersion?.remoteTrimmedNonEmpty else { return name }
        return "\(name) · \(version)"
    }

    var extractionSummary: String? {
        var parts: [String] = []
        if let doseGrams { parts.append(Self.grams(doseGrams, suffix: "in")) }
        if let yieldGrams { parts.append(Self.grams(yieldGrams, suffix: "out")) }
        if let brewTimeSeconds { parts.append("\(brewTimeSeconds) sec") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func grams(_ value: Double, suffix: String) -> String {
        let formatted = value.rounded() == value
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(formatted)g \(suffix)"
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
