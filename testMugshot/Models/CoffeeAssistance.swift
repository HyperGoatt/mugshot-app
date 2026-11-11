import Foundation

enum CoffeeAssistanceTask: String, Codable, CaseIterable, Identifiable, Sendable {
    case bagScan = "bag_scan"
    case recipeImport = "recipe_import"
    case memorySearch = "memory_search"
    case tasteInsight = "taste_insight"
    case brewExperiment = "brew_experiment"
    case weeklyReflection = "weekly_reflection"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bagScan: "Read this bag"
        case .recipeImport: "Read a recipe"
        case .memorySearch: "Find a memory"
        case .tasteInsight: "Notice a taste pattern"
        case .brewExperiment: "Experiment with Mugsy"
        case .weeklyReflection: "Reflect on this week"
        }
    }
    var allowedFieldKeys: Set<String> {
        switch self {
        case .bagScan: ["roaster", "name", "producer", "origin", "process", "variety", "roastLevel", "roastDate", "tastingNotes"]
        case .recipeImport: ["name", "ingredient", "step", "method", "notes", "creatorCredit", "sourceURL"]
        default: []
        }
    }
}

struct CoffeeAssistanceEvidence: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String

    init(id: String, title: String, detail: String) {
        self.id = id
        self.title = CoffeeAssistanceText.bound(title, to: 120)
        self.detail = CoffeeAssistanceText.bound(detail, to: 800)
    }
}

enum CoffeeAssistanceText {
    // Server limits count UTF-16 code units, including non-ASCII notes.
    static func bound(_ text: String, to limit: Int) -> String {
        String(decoding: text.utf16.prefix(limit), as: UTF16.self)
    }
}

struct CoffeeAssistanceRequest: Encodable, Sendable {
    let ownerID: UUID
    let requestID: UUID
    let task: CoffeeAssistanceTask
    let query: String
    let evidence: [CoffeeAssistanceEvidence]
    let image: String?

    init(ownerID: UUID, requestID: UUID = UUID(), task: CoffeeAssistanceTask,
         query: String = "", evidence: [CoffeeAssistanceEvidence], image: String? = nil) {
        self.ownerID = ownerID
        self.requestID = requestID
        self.task = task
        self.query = CoffeeAssistanceText.bound(query, to: 400)
        var characters = 0
        var ids = Set<String>()
        self.evidence = evidence.prefix(40).filter { item in
            characters += item.title.utf16.count + item.detail.utf16.count
            return characters <= 20_000 && ids.insert(item.id).inserted
        }
        self.image = image
    }

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id", requestID = "request_id", consentVersion = "consent_version"
        case task, query, evidence, image
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(ownerID, forKey: .ownerID)
        try values.encode(requestID, forKey: .requestID)
        try values.encode("selected-details-v1", forKey: .consentVersion)
        try values.encode(task, forKey: .task)
        try values.encode(query, forKey: .query)
        try values.encode(evidence, forKey: .evidence)
        if let image { try values.encode(image, forKey: .image) }
        else { try values.encodeNil(forKey: .image) }
    }
}

struct CoffeeAssistanceField: Codable, Equatable, Sendable {
    let key: String
    let value: String
    let sourceQuote: String
    var title: String {
        switch key {
        case "roastLevel": "Roast level"
        case "roastDate": "Roast date"
        case "tastingNotes": "Printed tasting notes"
        case "creatorCredit": "Creator credit"
        case "sourceURL": "Source link"
        default: key.prefix(1).uppercased() + String(key.dropFirst())
        }
    }
    enum CodingKeys: String, CodingKey {
        case key, value, sourceQuote = "source_quote"
    }
}

struct CoffeeAssistanceResult: Codable, Equatable, Sendable {
    let text: String
    let evidenceIDs: [String]
    let fields: [CoffeeAssistanceField]
    let searchTerms: [String]
    enum CodingKeys: String, CodingKey {
        case text, fields, evidenceIDs = "evidence_ids", searchTerms = "search_terms"
    }
    func validate(for request: CoffeeAssistanceRequest) throws {
        let ids = Set(request.evidence.map(\.id))
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf16.count <= 1600, evidenceIDs.count <= 40,
              Set(evidenceIDs).count == evidenceIDs.count,
              Set(evidenceIDs).isSubset(of: ids),
              request.evidence.isEmpty || !evidenceIDs.isEmpty,
              fields.count <= 24,
              fields.allSatisfy({ field in request.task.allowedFieldKeys.contains(field.key)
                  && !field.value.isEmpty && field.value.utf16.count <= 400
                  && !field.sourceQuote.isEmpty && field.sourceQuote.utf16.count <= 400
                  && (request.image != nil || request.evidence.contains { item in
                      item.title.contains(field.sourceQuote) || item.detail.contains(field.sourceQuote)
                  }) }),
              searchTerms.count <= 8, searchTerms.allSatisfy({ $0.utf16.count <= 80 }) else {
            throw CoffeeAssistanceError.invalidSuggestion
        }
    }
}

enum CoffeeAssistanceError: LocalizedError {
    case unavailable, accountChanged, consentRequired, invalidSuggestion
    var errorDescription: String? {
        switch self {
        case .accountChanged: "Your account changed. Open this helper again from your own journal."
        case .consentRequired: "Allow the selected details to be processed before asking for a suggestion."
        case .invalidSuggestion: "That suggestion could not be verified. Your original details are still available."
        case .unavailable: "Suggestions are unavailable right now. You can continue with your original details."
        }
    }
}

enum CoffeeAssistanceAnalyticsAction: String {
    case requested, succeeded, unavailable, accepted, cancelled
}
