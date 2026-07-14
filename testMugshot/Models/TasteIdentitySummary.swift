import Foundation

enum TasteSignalType: String, Codable, CaseIterable {
    case orderPreference = "order_preference"
    case sensoryEvaluation = "sensory_evaluation"

    var title: String {
        switch self {
        case .orderPreference: return "What you choose"
        case .sensoryEvaluation: return "What you notice"
        }
    }
}

enum TasteSignalOwnerState: String, Codable {
    case active
    case dismissed
    case corrected
}

struct RemoteTasteSignal: Identifiable, Decodable, Equatable {
    let id: UUID
    let userID: UUID
    let signalType: TasteSignalType
    let attribute: String
    let supportCount: Int
    let confidence: Double
    let averageScore: Double?
    let evidenceVisitIDs: [UUID]
    let calculationVersion: String
    let ownerState: TasteSignalOwnerState
    let ownerLabel: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, attribute, confidence
        case userID = "user_id"
        case signalType = "signal_type"
        case supportCount = "support_count"
        case averageScore = "average_score"
        case evidenceVisitIDs = "evidence_visit_ids"
        case calculationVersion = "calculation_version"
        case ownerState = "owner_state"
        case ownerLabel = "owner_label"
        case updatedAt = "updated_at"
    }

    var isDurableClaim: Bool { supportCount >= 3 && ownerState != .dismissed }

    var displayAttribute: String {
        if ownerState == .corrected, let ownerLabel = ownerLabel?.remoteTrimmedNonEmpty {
            return ownerLabel
        }
        let known: [String: String] = [
            "chooses_cold_drinks": "Cold drinks",
            "chooses_milk_drinks": "Milk drinks",
            "chooses_flavored_drinks": "Flavored drinks",
            "chooses_fruit_flavors": "Fruit flavors",
            "chooses_sweet_flavors": "Sweet flavors",
            "chooses_sweetened_drinks": "Sweetened drinks",
            "bean_clarity": "Bean clarity"
        ]
        return known[attribute] ?? attribute
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var claimText: String {
        switch signalType {
        case .orderPreference:
            return "\(displayAttribute) appear often in your orders"
        case .sensoryEvaluation:
            if let averageScore {
                return String(format: "%@ averages %.1f in your tasting lens", displayAttribute, averageScore)
            }
            return "\(displayAttribute) is part of your tasting lens"
        }
    }

    var evidenceSummary: String {
        "Based on \(supportCount) distinct \(supportCount == 1 ? "sip" : "sips")"
    }

    var systemImage: String {
        signalType == .orderPreference ? "cup.and.saucer.fill" : "slider.horizontal.3"
    }
}

struct TasteIdentityPattern: Equatable, Identifiable {
    let text: String
    let systemImage: String

    var id: String { text }
}

struct TasteIdentitySummary: Equatable {
    let title: String
    let descriptors: [String]
    let description: String
    let patterns: [TasteIdentityPattern]
    let isForming: Bool

    static let possiblePassportTitles = 512

    static let empty = TasteIdentitySummary(
        title: "Your Mugshot Passport is forming",
        descriptors: ["Taste forming", "Lens forming", "Ritual forming"],
        description: "Every journal entry gives Mugshot a little more to learn from.",
        patterns: [
            TasteIdentityPattern(text: "Log a sip to begin your taste story", systemImage: "sparkles")
        ],
        isForming: true
    )

    static func calculate(from visits: [RemoteVisitSummary]) -> TasteIdentitySummary {
        guard !visits.isEmpty else { return .empty }

        let homeVisits = visits.filter { $0.visit.journalContext != .cafe }
        let cafeVisits = visits.filter { $0.visit.journalContext == .cafe }
        let topCafe = Dictionary(grouping: cafeVisits.compactMap(\.cafe), by: \.id)
            .values
            .sorted { $0.count > $1.count }
            .first

        let title: String
        let description: String
        if !homeVisits.isEmpty && !cafeVisits.isEmpty {
            title = "The Neighborhood Experimenter"
            description = "You return to familiar cafes, then tune the details at home."
        } else if !homeVisits.isEmpty {
            title = "The Home Dialer"
            description = "You learn cup by cup, keeping the variables that make a brew click."
        } else if let topCafe, topCafe.count >= 2 {
            title = "The Neighborhood Regular"
            description = "You build taste memory by returning to places that feel like yours."
        } else {
            title = "The Curious Sipper"
            description = "You follow good drinks across new cafes and changing flavors."
        }

        var patterns: [TasteIdentityPattern] = []

        let drinkCounts = Dictionary(grouping: visits, by: { $0.visit.drinkCategoryDisplayName ?? $0.visit.drinkDisplayName })
            .mapValues(\.count)
        if let favorite = drinkCounts.max(by: { $0.value < $1.value }) {
            patterns.append(TasteIdentityPattern(
                text: "\(favorite.key) anchors \(favorite.value) of your journal entries",
                systemImage: "cup.and.saucer.fill"
            ))
        }

        let methods = homeVisits.compactMap { $0.visit.brewMethod?.remoteTrimmedNonEmpty }
        if let method = Dictionary(grouping: methods, by: { $0 }).mapValues(\.count).max(by: { $0.value < $1.value })?.key {
            patterns.append(TasteIdentityPattern(
                text: "\(method) is your most-used home method",
                systemImage: "dial.high.fill"
            ))
        } else if let topCafe, let cafe = topCafe.first {
            patterns.append(TasteIdentityPattern(
                text: "You keep finding your way back to \(cafe.consumerDisplayName)",
                systemImage: "mappin.circle.fill"
            ))
        }

        let extractions = homeVisits.compactMap { visit -> (Double, Double, Int)? in
            let details = visit.visit.structuredBrewDetails
            guard let dose = details.doseGrams,
                  let output = details.yieldGrams,
                  let seconds = details.brewTimeSeconds,
                  dose > 0 else { return nil }
            return (dose, output, seconds)
        }
        if !extractions.isEmpty {
            let averageRatio = extractions.reduce(0.0) { $0 + ($1.1 / $1.0) } / Double(extractions.count)
            let minSeconds = extractions.map(\.2).min() ?? 0
            let maxSeconds = extractions.map(\.2).max() ?? 0
            patterns.append(TasteIdentityPattern(
                text: String(format: "Best-known espresso range: 1:%.1f in %d–%d sec", averageRatio, minSeconds, maxSeconds),
                systemImage: "timer"
            ))
        } else if !homeVisits.isEmpty {
            let homeAverage = homeVisits.reduce(0.0) { $0 + $1.visit.overallScore } / Double(homeVisits.count)
            patterns.append(TasteIdentityPattern(
                text: String(format: "Home experiments average %.1f so far", homeAverage),
                systemImage: "house.fill"
            ))
        } else {
            let uniqueCafeCount = Set(cafeVisits.compactMap { $0.cafe?.id }).count
            patterns.append(TasteIdentityPattern(
                text: "Your journal spans \(uniqueCafeCount) \(uniqueCafeCount == 1 ? "cafe" : "cafes")",
                systemImage: "map.fill"
            ))
        }

        return TasteIdentitySummary(
            title: title,
            descriptors: legacyDescriptors(from: visits),
            description: description,
            patterns: Array(patterns.prefix(3)),
            isForming: visits.count < 3
        )
    }

    static func calculate(from signals: [RemoteTasteSignal]) -> TasteIdentitySummary {
        calculate(from: signals, visits: [])
    }

    static func calculate(
        from signals: [RemoteTasteSignal],
        visits: [RemoteVisitSummary]
    ) -> TasteIdentitySummary {
        let durable = signals.filter(\.isDurableClaim)
        guard !durable.isEmpty else { return .empty }

        let sensoryCount = durable.filter { $0.signalType == .sensoryEvaluation }.count
        let orderCount = durable.filter { $0.signalType == .orderPreference }.count
        let descriptors = passportDescriptors(signals: durable, visits: visits)
        let title = passportTitle(descriptors: descriptors)
        let description: String
        if sensoryCount > 0, orderCount > 0 {
            description = "A tasting business card built from what you choose, what you notice, and where coffee fits into your life."
        } else if sensoryCount > 0 {
            description = "These patterns come only from qualities you rated in your tasting lens."
        } else {
            description = "These are recurring choices, not claims about how a specific drink tasted."
        }

        return TasteIdentitySummary(
            title: title,
            descriptors: descriptors,
            description: description,
            patterns: durable.prefix(3).map {
                TasteIdentityPattern(text: $0.claimText, systemImage: $0.systemImage)
            },
            isForming: false
        )
    }

    static func publicPassport(from visits: [PublicProfileVisit]) -> TasteIdentitySummary {
        guard visits.count >= 3 else { return .empty }
        let descriptors = publicPassportDescriptors(visits: visits)
        let patterns = publicPatterns(visits: visits)
        return TasteIdentitySummary(
            title: passportTitle(descriptors: descriptors),
            descriptors: descriptors,
            description: "Built only from sips this person has chosen to share with you.",
            patterns: patterns,
            isForming: false
        )
    }

    private static func passportDescriptors(
        signals: [RemoteTasteSignal],
        visits: [RemoteVisitSummary]
    ) -> [String] {
        [
            orderDescriptor(signals: signals, drinkNames: visits.map { $0.visit.drinkDisplayName }),
            lensDescriptor(signals: signals),
            ritualDescriptor(
                contexts: visits.map { $0.visit.journalContext },
                cafeIDs: visits.compactMap { $0.cafe?.id },
                companionCounts: visits.map { $0.visit.structuredBrewDetails.companions?.count ?? 0 }
            )
        ]
    }

    private static func publicPassportDescriptors(visits: [PublicProfileVisit]) -> [String] {
        let ratingNames = visits.flatMap { ($0.ratings ?? [:]).keys }
        let contexts = visits.map(\.journalContext)
        return [
            orderDescriptor(signals: [], drinkNames: visits.map(\.drinkDisplayName)),
            publicLensDescriptor(ratingNames: ratingNames),
            ritualDescriptor(
                contexts: contexts,
                cafeIDs: visits.compactMap(\.cafeID),
                companionCounts: Array(repeating: 0, count: visits.count)
            )
        ]
    }

    private static func orderDescriptor(
        signals: [RemoteTasteSignal],
        drinkNames: [String]
    ) -> String {
        let attributes = Set(signals.filter { $0.signalType == .orderPreference }.map(\.attribute))
        if attributes.contains("chooses_fruit_flavors") { return "Fruit-Forward" }
        if attributes.contains("chooses_sweet_flavors") || attributes.contains("chooses_sweetened_drinks") { return "Sweet-Toothed" }
        if attributes.contains("chooses_flavored_drinks") { return "Flavor-Curious" }
        if attributes.contains("chooses_cold_drinks") { return "Cold-Drink Loyalist" }
        if attributes.contains("chooses_milk_drinks") { return "Milk-Forward" }

        let normalized = drinkNames.map { $0.localizedLowercase }
        if normalized.filter({ $0.contains("matcha") }).count * 2 >= max(1, normalized.count) { return "Matcha-Minded" }
        if normalized.filter({ $0.contains("tea") || $0.contains("chai") || $0.contains("hojicha") }).count * 2 >= max(1, normalized.count) { return "Tea-Curious" }
        if normalized.contains(where: { $0.contains("pour over") || $0.contains("chemex") || $0.contains("v60") }) { return "Brew-Method Curious" }
        return "Coffee-First"
    }

    private static func lensDescriptor(signals: [RemoteTasteSignal]) -> String {
        guard let strongest = signals
            .filter({ $0.signalType == .sensoryEvaluation })
            .max(by: { lhs, rhs in
                let left = Double(lhs.supportCount) * lhs.confidence
                let right = Double(rhs.supportCount) * rhs.confidence
                return left < right
            }) else { return "Detail-Driven" }
        return lensDescriptor(attribute: strongest.attribute)
    }

    private static func publicLensDescriptor(ratingNames: [String]) -> String {
        let counts = Dictionary(grouping: ratingNames.map { $0.localizedLowercase }, by: { $0 }).mapValues(\.count)
        guard let strongest = counts.max(by: { $0.value < $1.value })?.key else { return "Detail-Driven" }
        return lensDescriptor(attribute: strongest)
    }

    private static func lensDescriptor(attribute: String) -> String {
        switch attribute.localizedLowercase.replacingOccurrences(of: " ", with: "_") {
        case "ambiance": return "Ambiance-Led"
        case "presentation": return "Presentation-Led"
        case "taste": return "Taste-Led"
        case "aroma": return "Aroma-Led"
        case "mouthfeel", "texture": return "Texture-Led"
        case "value": return "Value-Aware"
        case "bean_clarity", "clarity": return "Clarity-Seeking"
        case "balance": return "Balance-Seeking"
        case "service": return "Hospitality-Minded"
        default: return "Detail-Driven"
        }
    }

    private static func ritualDescriptor(
        contexts: [JournalEntryContext],
        cafeIDs: [UUID],
        companionCounts: [Int]
    ) -> String {
        let cafeCount = contexts.filter { $0 == .cafe }.count
        let homeCount = contexts.filter { $0 == .home }.count
        let recipeCount = contexts.filter { $0 == .recipe }.count
        if recipeCount >= 2 { return "Recipe Builder" }
        if companionCounts.reduce(0, +) >= 3 { return "Social Sipper" }
        if homeCount > cafeCount { return "Home Dialer" }
        let cafeFrequency = Dictionary(grouping: cafeIDs, by: { $0 }).mapValues(\.count)
        if cafeFrequency.values.max() ?? 0 >= 3 { return "Neighborhood Regular" }
        if Set(cafeIDs).count >= 3 { return "Cafe Explorer" }
        if homeCount > 0, cafeCount > 0 { return "Ritual Mixer" }
        return cafeCount > 0 ? "Cafe Explorer" : "Memory Keeper"
    }

    private static func passportTitle(descriptors: [String]) -> String {
        let seeds = ["Orchard", "Velvet", "Ember", "Meadow", "Citrus", "Cocoa", "Honey", "Classic"]
        let moods = ["Curious", "Textural", "Thoughtful", "Precise", "Expressive", "Balanced", "Story-Led", "Detail-Minded"]
        let roles = ["Cartographer", "Ritualist", "Alchemist", "Archivist", "Explorer", "Host", "Tinkerer", "Voyager"]
        let first = descriptors.indices.contains(0) ? descriptors[0] : "Taste forming"
        let second = descriptors.indices.contains(1) ? descriptors[1] : "Lens forming"
        let third = descriptors.indices.contains(2) ? descriptors[2] : "Ritual forming"
        return "The \(moods[stableIndex(second, count: moods.count)]) \(seeds[stableIndex(first, count: seeds.count)]) \(roles[stableIndex(third, count: roles.count)])"
    }

    private static func stableIndex(_ value: String, count: Int) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private static func legacyDescriptors(from visits: [RemoteVisitSummary]) -> [String] {
        [
            orderDescriptor(signals: [], drinkNames: visits.map { $0.visit.drinkDisplayName }),
            "Detail-Driven",
            ritualDescriptor(
                contexts: visits.map { $0.visit.journalContext },
                cafeIDs: visits.compactMap { $0.cafe?.id },
                companionCounts: visits.map { $0.visit.structuredBrewDetails.companions?.count ?? 0 }
            )
        ]
    }

    private static func publicPatterns(visits: [PublicProfileVisit]) -> [TasteIdentityPattern] {
        var patterns: [TasteIdentityPattern] = []
        let drinkCounts = Dictionary(grouping: visits.map(\.drinkDisplayName), by: { $0 }).mapValues(\.count)
        if let favorite = drinkCounts.max(by: { $0.value < $1.value }) {
            patterns.append(TasteIdentityPattern(
                text: "\(favorite.key) appears in \(favorite.value) shared \(favorite.value == 1 ? "sip" : "sips")",
                systemImage: "cup.and.saucer.fill"
            ))
        }
        let ratingNames = visits.flatMap { ($0.ratings ?? [:]).keys }
        if let mostUsed = Dictionary(grouping: ratingNames, by: { $0 }).mapValues(\.count).max(by: { $0.value < $1.value }) {
            patterns.append(TasteIdentityPattern(
                text: "\(mostUsed.key.capitalized) is a recurring part of their tasting lens",
                systemImage: "slider.horizontal.3"
            ))
        }
        let cafeCount = Set(visits.compactMap(\.cafeID)).count
        patterns.append(TasteIdentityPattern(
            text: "Their visible journal spans \(cafeCount) \(cafeCount == 1 ? "cafe" : "cafes")",
            systemImage: "map.fill"
        ))
        return Array(patterns.prefix(3))
    }
}
