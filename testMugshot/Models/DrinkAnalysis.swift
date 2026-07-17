import Foundation

enum SipComposerExperience: String, Codable, CaseIterable, Identifiable {
    case longForm
    case guided

    static let storageKey = "MugshotComposer.experience.v1"
    static let defaultExperience: SipComposerExperience = .guided

    var id: String { rawValue }

    var title: String {
        switch self {
        case .longForm: return "Long Form"
        case .guided: return "Guided"
        }
    }
}

enum SipGuidedStep: String, Codable, CaseIterable {
    case context
    case drink
    case rating
    /// Keeps the legacy raw value so in-progress drafts saved on the former
    /// optional-details step restore into the new audience step.
    case audience = "memory"

    var number: Int {
        switch self {
        case .context: return 1
        case .drink: return 2
        case .rating: return 3
        case .audience: return 4
        }
    }
}

enum ServingVolumeUnit: String, CaseIterable, Identifiable {
    case fluidOunces
    case milliliters

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .fluidOunces: return "oz"
        case .milliliters: return "mL"
        }
    }

    static var preferredForCurrentLocale: ServingVolumeUnit {
        Locale.current.measurementSystem == .us ? .fluidOunces : .milliliters
    }

    func displayValue(fromMilliliters milliliters: Double) -> Double {
        switch self {
        case .fluidOunces: return milliliters / 29.5735
        case .milliliters: return milliliters
        }
    }

    func milliliters(fromDisplayValue value: Double) -> Double {
        switch self {
        case .fluidOunces: return value * 29.5735
        case .milliliters: return value
        }
    }
}

enum DrinkFamily: String, Codable, CaseIterable {
    case espresso
    case brewedCoffee = "brewed_coffee"
    case matcha
    case hojicha
    case tea
    case chai
    case hotChocolate = "hot_chocolate"
    case unknown

    var legacyDrinkType: DrinkType {
        switch self {
        case .espresso, .brewedCoffee: return .coffee
        case .matcha: return .matcha
        case .hojicha: return .hojicha
        case .tea: return .tea
        case .chai: return .chai
        case .hotChocolate: return .hotChocolate
        case .unknown: return .other
        }
    }
}

enum DrinkPreparation: String, Codable, CaseIterable {
    case espresso
    case americano
    case latte
    case cappuccino
    case cortado
    case flatWhite = "flat_white"
    case mocha
    case macchiato
    case drip
    case pourOver = "pour_over"
    case chemex
    case frenchPress = "french_press"
    case aeropress
    case coldBrew = "cold_brew"
    case matcha
    case hojicha
    case tea
    case chai
    case hotChocolate = "hot_chocolate"
    case unknown

    var isEspressoBased: Bool {
        switch self {
        case .espresso, .americano, .latte, .cappuccino, .cortado, .flatWhite, .mocha, .macchiato:
            return true
        default:
            return false
        }
    }
}

enum DrinkTemperature: String, Codable {
    case hot
    case iced
    case frozen
    case coldBrew = "cold_brew"
}

enum DrinkCaffeineModifier: String, Codable {
    case regular
    case halfCaf = "half_caf"
    case decaf
}

enum DrinkAnalysisCoverage: String, Codable {
    case estimated
    case excluded
}

struct DrinkAnalysis: Codable, Equatable {
    static let schemaVersion = 1
    static let localParserVersion = "local-rules-1"
    static let caffeineReferenceVersion = "traditional-averages-1"

    var rawDrinkName: String
    var family: DrinkFamily
    var preparation: DrinkPreparation
    var temperature: DrinkTemperature
    var caffeineModifier: DrinkCaffeineModifier
    var espressoShotCount: Int?
    var servingVolumeMilliliters: Double?
    var milk: String?
    var flavors: [String]
    var additions: [String]
    var orderPreferenceSignals: [String]
    var estimatedCaffeineMilligrams: Double?
    var caffeineCalculationBasis: String?
    var coverage: DrinkAnalysisCoverage
    var confidence: Double
    var schemaVersion: Int
    var parserVersion: String
    var caffeineReferenceVersion: String
    var provenance: String
    var userOverrides: [String: String]

    var legacyDrinkType: DrinkType { family.legacyDrinkType }

    var legacyCustomDrinkType: String? {
        family == .unknown ? rawDrinkName.remoteTrimmedNonEmpty : nil
    }
}

enum DrinkAnalysisParser {
    static func analyze(
        _ rawDrinkName: String,
        servingVolumeMilliliters: Double? = nil,
        explicitShotCount: Int? = nil,
        userOverrides: [String: String] = [:]
    ) -> DrinkAnalysis {
        let raw = rawDrinkName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalize(raw)
        let preparation = preparation(in: normalized)
        let family = family(for: preparation, normalized: normalized)
        let temperature = temperature(in: normalized, preparation: preparation)
        let caffeineModifier = caffeineModifier(in: normalized)
        let shotCount = resolvedShotCount(
            in: normalized,
            preparation: preparation,
            explicitShotCount: explicitShotCount
        )
        let milk = firstMatch(in: normalized, values: milkTerms)
        let flavors = allMatches(in: normalized, values: flavorTerms)
        let additions = allMatches(in: normalized, values: additionTerms)
        let preferenceSignals = preferenceSignals(
            normalized: normalized,
            temperature: temperature,
            milk: milk,
            flavors: flavors
        )
        let estimate = CaffeineReferenceTable.estimate(
            preparation: preparation,
            modifier: caffeineModifier,
            shotCount: shotCount,
            servingVolumeMilliliters: servingVolumeMilliliters
        )

        return DrinkAnalysis(
            rawDrinkName: raw,
            family: family,
            preparation: preparation,
            temperature: temperature,
            caffeineModifier: caffeineModifier,
            espressoShotCount: shotCount,
            servingVolumeMilliliters: servingVolumeMilliliters,
            milk: milk,
            flavors: flavors,
            additions: additions,
            orderPreferenceSignals: preferenceSignals,
            estimatedCaffeineMilligrams: estimate?.milligrams,
            caffeineCalculationBasis: estimate?.basis,
            coverage: estimate == nil ? .excluded : .estimated,
            confidence: confidence(for: preparation, raw: raw),
            schemaVersion: DrinkAnalysis.schemaVersion,
            parserVersion: DrinkAnalysis.localParserVersion,
            caffeineReferenceVersion: DrinkAnalysis.caffeineReferenceVersion,
            provenance: "local_rules",
            userOverrides: userOverrides
        )
    }

    private static let milkTerms = [
        "oat milk", "almond milk", "soy milk", "coconut milk", "whole milk",
        "skim milk", "2% milk", "half and half", "macadamia milk", "cashew milk",
        "pea milk", "rice milk", "lactose free milk", "cream"
    ]

    private static let flavorTerms = [
        "strawberry", "cherry", "orange", "peach", "raspberry", "blueberry",
        "vanilla", "caramel", "hazelnut", "cinnamon", "cardamom", "honey",
        "maple", "lavender", "rose", "pistachio", "chocolate"
    ]

    private static let additionTerms = [
        "syrup", "sugar", "sweetener", "cold foam", "whipped cream", "boba",
        "lemon", "ginger"
    ]

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func preparation(in value: String) -> DrinkPreparation {
        let matches: [(DrinkPreparation, [String])] = [
            (.coldBrew, ["cold brew", "nitro"]),
            (.flatWhite, ["flat white"]),
            (.pourOver, ["pour over", "v60", "kalita"]),
            (.frenchPress, ["french press"]),
            (.hotChocolate, ["hot chocolate", "cocoa"]),
            (.cappuccino, ["cappuccino"]),
            (.americano, ["americano"]),
            (.macchiato, ["macchiato"]),
            (.cortado, ["cortado"]),
            (.espresso, ["espresso", "doppio", "ristretto", "lungo"]),
            (.chemex, ["chemex"]),
            (.aeropress, ["aeropress"]),
            (.drip, ["drip", "batch brew", "filter coffee"]),
            (.mocha, ["mocha"]),
            (.latte, ["latte"]),
            (.matcha, ["matcha"]),
            (.hojicha, ["hojicha"]),
            (.chai, ["chai"]),
            (.tea, ["tea"])
        ]

        for (preparation, terms) in matches where terms.contains(where: value.contains) {
            return preparation
        }
        return .unknown
    }

    private static func family(for preparation: DrinkPreparation, normalized: String) -> DrinkFamily {
        // A preparation word such as "latte" describes format, not the base
        // ingredient. Resolve named tea bases first so matcha, hojicha, and chai
        // lattes receive their tea sensory pack plus the milk overlay instead of
        // being treated as espresso drinks.
        if normalized.contains("matcha") { return .matcha }
        if normalized.contains("hojicha") { return .hojicha }
        if normalized.contains("chai") { return .chai }
        if normalized.contains("hot chocolate") || normalized.contains("cocoa") {
            return .hotChocolate
        }

        switch preparation {
        case .espresso, .americano, .latte, .cappuccino, .cortado, .flatWhite, .mocha, .macchiato:
            return .espresso
        case .drip, .pourOver, .chemex, .frenchPress, .aeropress, .coldBrew:
            return .brewedCoffee
        case .matcha: return .matcha
        case .hojicha: return .hojicha
        case .tea: return .tea
        case .chai: return .chai
        case .hotChocolate: return .hotChocolate
        case .unknown:
            if normalized.contains("coffee") { return .brewedCoffee }
            return .unknown
        }
    }

    private static func temperature(
        in value: String,
        preparation: DrinkPreparation
    ) -> DrinkTemperature {
        if preparation == .coldBrew { return .coldBrew }
        if ["frozen", "frappe", "frappé", "blended"].contains(where: value.contains) { return .frozen }
        let temperatureText = value.replacingOccurrences(of: "cold foam", with: "")
        if ["iced", "ice ", "cold ", "chilled"].contains(where: temperatureText.contains) { return .iced }
        return .hot
    }

    private static func caffeineModifier(in value: String) -> DrinkCaffeineModifier {
        if value.contains("half caf") || value.contains("half-caf") { return .halfCaf }
        if value.contains("decaf") { return .decaf }
        return .regular
    }

    private static func resolvedShotCount(
        in value: String,
        preparation: DrinkPreparation,
        explicitShotCount: Int?
    ) -> Int? {
        if let explicitShotCount, explicitShotCount > 0 { return min(explicitShotCount, 8) }

        let wordCounts: [(String, Int)] = [
            ("single", 1), ("double", 2), ("doppio", 2), ("triple", 3), ("quad", 4)
        ]
        if let match = wordCounts.first(where: { value.contains($0.0) }) { return match.1 }

        let pattern = #"\b([1-8])\s*(?:espresso\s*)?shots?\b"#
        if let expression = try? NSRegularExpression(pattern: pattern),
           let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let range = Range(match.range(at: 1), in: value),
           let count = Int(value[range]) {
            return count
        }

        return preparation.isEspressoBased ? 2 : nil
    }

    private static func firstMatch(in value: String, values: [String]) -> String? {
        values.first(where: value.contains)
    }

    private static func allMatches(in value: String, values: [String]) -> [String] {
        values.filter(value.contains)
    }

    private static func preferenceSignals(
        normalized: String,
        temperature: DrinkTemperature,
        milk: String?,
        flavors: [String]
    ) -> [String] {
        var signals: [String] = []
        if temperature != .hot { signals.append("chooses_cold_drinks") }
        if milk != nil { signals.append("chooses_milk_drinks") }
        if !flavors.isEmpty { signals.append("chooses_flavored_drinks") }
        if flavorTerms.prefix(6).contains(where: normalized.contains) {
            signals.append("chooses_fruit_flavors")
            signals.append("chooses_sweet_flavors")
        }
        if ["syrup", "sugar", "sweet", "honey", "caramel", "vanilla"].contains(where: normalized.contains) {
            signals.append("chooses_sweetened_drinks")
        }
        return Array(Set(signals)).sorted()
    }

    private static func confidence(for preparation: DrinkPreparation, raw: String) -> Double {
        guard !raw.isEmpty else { return 0 }
        return preparation == .unknown ? 0.25 : 0.9
    }
}

enum CaffeineReferenceTable {
    struct Estimate: Equatable {
        let milligrams: Double
        let basis: String
    }

    static func estimate(
        preparation: DrinkPreparation,
        modifier: DrinkCaffeineModifier,
        shotCount: Int?,
        servingVolumeMilliliters: Double?
    ) -> Estimate? {
        if preparation.isEspressoBased {
            let shots = max(shotCount ?? 2, 1)
            let perShot = modifier == .decaf ? 6.0 : 63.0
            let amount = adjusted(perShot * Double(shots), modifier: modifier, decafAlreadyApplied: true)
            return Estimate(
                milligrams: rounded(amount),
                basis: "\(shots) espresso shot\(shots == 1 ? "" : "s") at the traditional average"
            )
        }

        let reference: (milligrams: Double, milliliters: Double, label: String)?
        switch preparation {
        case .drip: reference = (95, 240, "drip coffee")
        case .pourOver: reference = (120, 300, "pour-over coffee")
        case .chemex: reference = (120, 300, "Chemex")
        case .frenchPress: reference = (107, 240, "French press")
        case .aeropress: reference = (80, 240, "AeroPress")
        case .coldBrew: reference = (200, 355, "cold brew")
        case .matcha: reference = (70, 240, "matcha")
        case .hojicha: reference = (30, 240, "hojicha")
        case .tea: reference = (47, 240, "tea")
        case .chai: reference = (40, 240, "chai")
        case .hotChocolate: reference = (9, 240, "hot chocolate")
        case .espresso, .americano, .latte, .cappuccino, .cortado, .flatWhite, .mocha, .macchiato, .unknown:
            reference = nil
        }

        guard let reference else { return nil }
        let serving = max(servingVolumeMilliliters ?? reference.milliliters, 30)
        let scaled = reference.milligrams * serving / reference.milliliters
        let amount: Double
        if modifier == .decaf {
            amount = 3 * serving / 240
        } else {
            amount = adjusted(scaled, modifier: modifier, decafAlreadyApplied: false)
        }
        return Estimate(
            milligrams: rounded(amount),
            basis: "\(reference.label) traditional average scaled to \(Int(serving.rounded())) mL"
        )
    }

    private static func adjusted(
        _ amount: Double,
        modifier: DrinkCaffeineModifier,
        decafAlreadyApplied: Bool
    ) -> Double {
        switch modifier {
        case .regular: return amount
        case .halfCaf: return amount * 0.5
        case .decaf: return decafAlreadyApplied ? amount : amount * 0.05
        }
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
