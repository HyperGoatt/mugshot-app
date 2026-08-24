import Foundation

struct JournalEntryProjection: Identifiable, Equatable {
    let summary: RemoteVisitSummary
    let privateNote: String?
    let isBookmarked: Bool
    let drinkAnalysis: JournalDrinkAnalysis?

    init(
        summary: RemoteVisitSummary,
        privateNote: String?,
        isBookmarked: Bool,
        drinkAnalysis: JournalDrinkAnalysis? = nil
    ) {
        self.summary = summary
        self.privateNote = privateNote
        self.isBookmarked = isBookmarked
        self.drinkAnalysis = drinkAnalysis
    }

    var id: UUID { summary.id }
    var date: Date { summary.visit.createdAtDate }
    var context: JournalEntryContext { summary.visit.journalContext }
    var tags: [String] { summary.visit.structuredBrewDetails.tags ?? [] }

    func matches(_ rawQuery: String) -> Bool {
        guard let query = rawQuery.remoteTrimmedNonEmpty?.localizedLowercase else { return true }
        let brew = summary.visit.structuredBrewDetails
        let coffee = brew.coffeeBag
        var searchable: [String] = [
            summary.visit.drinkDisplayName,
            summary.locationTitle,
            summary.visit.caption,
            privateNote ?? "",
            summary.visit.brewMethod ?? "",
            summary.visit.equipment ?? "",
            coffee?.displayName ?? "",
            coffee?.producer ?? "",
            coffee?.origin ?? "",
            coffee?.process ?? "",
            coffee?.variety ?? "",
            brew.beans ?? "",
            brew.beanOrigin ?? "",
            brew.grindSetting ?? ""
        ]
        if let equipmentSnapshots = brew.equipmentSnapshots {
            for equipment in equipmentSnapshots {
                searchable.append(contentsOf: [
                    equipment.displayName,
                    equipment.brand ?? "",
                    equipment.model ?? ""
                ])
            }
        }
        searchable.append(contentsOf: tags)
        return searchable.contains { $0.localizedLowercase.contains(query) }
    }
}

struct JournalDrinkAnalysis: Decodable, Equatable {
    let visitID: UUID
    let processingStatus: String
    let preparation: String?
    let caffeineModifier: String?
    let estimatedCaffeineMilligrams: Double?
    let caffeineCalculationBasis: String?
    let caffeineCoverage: String
    let caffeineReferenceVersion: String
    let parserVersion: String
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case processingStatus = "processing_status"
        case preparation
        case caffeineModifier = "caffeine_modifier"
        case estimatedCaffeineMilligrams = "estimated_caffeine_mg"
        case caffeineCalculationBasis = "caffeine_calculation_basis"
        case caffeineCoverage = "caffeine_coverage"
        case caffeineReferenceVersion = "caffeine_reference_version"
        case parserVersion = "parser_version"
        case confidence
    }

    var isCoveredEstimate: Bool {
        processingStatus == "complete"
            && caffeineCoverage == DrinkAnalysisCoverage.estimated.rawValue
            && estimatedCaffeineMilligrams != nil
    }
}
struct JournalBookmarkRow: Decodable, Equatable {
    let visitID: UUID

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
    }
}

struct JournalPrivateNoteRow: Decodable, Equatable {
    let visitID: UUID
    let note: String

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case note
    }
}
