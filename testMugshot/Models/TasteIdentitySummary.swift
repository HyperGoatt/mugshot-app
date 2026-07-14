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
    let description: String
    let patterns: [TasteIdentityPattern]

    static let empty = TasteIdentitySummary(
        title: "Your taste is taking shape",
        description: "Every journal entry gives Mugshot a little more to learn from.",
        patterns: [
            TasteIdentityPattern(text: "Log a sip to begin your taste story", systemImage: "sparkles")
        ]
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
            description: description,
            patterns: Array(patterns.prefix(3))
        )
    }

    static func calculate(from signals: [RemoteTasteSignal]) -> TasteIdentitySummary {
        let durable = signals.filter(\.isDurableClaim)
        guard !durable.isEmpty else { return .empty }

        let sensoryCount = durable.filter { $0.signalType == .sensoryEvaluation }.count
        let orderCount = durable.filter { $0.signalType == .orderPreference }.count
        let title: String
        let description: String
        if sensoryCount > 0, orderCount > 0 {
            title = "Your evolving taste"
            description = "Mugshot separates what you choose from what you explicitly notice in the cup."
        } else if sensoryCount > 0 {
            title = "Your tasting language"
            description = "These patterns come only from qualities you rated in your tasting lens."
        } else {
            title = "Your order patterns"
            description = "These are recurring choices, not claims about how a specific drink tasted."
        }

        return TasteIdentitySummary(
            title: title,
            description: description,
            patterns: durable.prefix(3).map {
                TasteIdentityPattern(text: $0.claimText, systemImage: $0.systemImage)
            }
        )
    }
}
