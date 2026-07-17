import Foundation

// MARK: - Core response semantics

enum TastingDepth: String, Codable, CaseIterable, Identifiable {
    case quick
    case guided
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .guided: return "Guided"
        case .deep: return "Deep"
        }
    }
}

enum SensoryDimension: String, Codable, CaseIterable {
    case identity
    case appearance
    case aroma
    case taste
    case flavor
    case body
    case texture
    case astringency
    case finish
    case temperatureChange = "temperature_change"
    case integration
    case balance
    case unexpected
    case personalResponse = "personal_response"
}

enum SensoryStage: String, Codable, CaseIterable {
    case ownWords = "own_words"
    case appearance
    case aroma
    case firstSip = "first_sip"
    case flavor
    case mouthfeel
    case finish
    case temperature
    case structure
    case personal

    var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

enum SensoryMeasureType: String, Codable, CaseIterable {
    /// Unstructured user language, always collected before suggestions in Guided and Deep.
    case ownWords = "own_words"
    case presence
    case intensity
    case singleChoice = "single_choice"
    case multipleChoice = "multiple_choice"
    case duration
    case preference
    case confidence
    case qualityImpression = "quality_impression"
    /// The only measure in Tasting Lens that accepts 0.5 increments.
    case overallEnjoyment = "overall_enjoyment"
}

enum SensoryResponseState: String, Codable, CaseIterable {
    case notAsked = "not_asked"
    case skipped
    case notPresent = "not_present"
    case unsure
    case observed
    case notRelevant = "not_relevant"

    var contributesSensoryEvidence: Bool {
        self == .observed || self == .notPresent
    }
}

enum SensoryConfidence: String, Codable, CaseIterable {
    case learning
    case maybe
    case sure

    var title: String {
        switch self {
        case .learning: return "I'm still learning"
        case .maybe: return "Maybe"
        case .sure: return "I'm sure"
        }
    }
}

enum SensoryPreference: String, Codable, CaseIterable {
    case notForMe = "not_for_me"
    case neutral
    case liked

    var title: String {
        switch self {
        case .notForMe: return "Not for me"
        case .neutral: return "Neutral"
        case .liked: return "I liked it"
        }
    }
}

enum SensorySuggestionOrigin: String, Codable, CaseIterable {
    case neutralPrompt = "neutral_prompt"
    case basePack = "base_pack"
    case modifierOverlay = "modifier_overlay"
    case userPinned = "user_pinned"
    case learnedPattern = "learned_pattern"
    case custom
    case aiCandidate = "ai_candidate"
}

enum SensoryIntensityScale: String, Codable, CaseIterable {
    case consumerThree = "consumer_intensity_3"
    case deepFive = "deep_intensity_5"

    var validRange: ClosedRange<Int> {
        switch self {
        case .consumerThree: return 1...3
        case .deepFive: return 1...5
        }
    }
}

struct SensoryIntensityValue: Codable, Equatable {
    let scale: SensoryIntensityScale
    let level: Int

    init?(scale: SensoryIntensityScale, level: Int) {
        guard scale.validRange.contains(level) else { return nil }
        self.scale = scale
        self.level = level
    }

    private enum CodingKeys: String, CodingKey { case scale, level }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let scale = try container.decode(SensoryIntensityScale.self, forKey: .scale)
        let level = try container.decode(Int.self, forKey: .level)
        guard scale.validRange.contains(level) else {
            throw DecodingError.dataCorruptedError(
                forKey: .level,
                in: container,
                debugDescription: "Intensity level is outside the declared scale."
            )
        }
        self.scale = scale
        self.level = level
    }
}

struct SensoryQualityImpression: Codable, Equatable {
    let value: Int

    init?(_ value: Int) {
        guard (1...5).contains(value) else { return nil }
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard (1...5).contains(value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Quality impression must be a whole value from 1 through 5.")
        }
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

enum SensoryDurationValue: Int, Codable, CaseIterable {
    case quick = 1
    case medium = 2
    case lingering = 3

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .medium: return "Medium"
        case .lingering: return "Lingering"
        }
    }
}

/// Independent personal enjoyment. No sensory criterion contributes to this value.
struct PersonalEnjoymentRating: Codable, Equatable, Comparable {
    let halfSteps: Int

    init?(value: Double) {
        let scaled = value * 2
        guard (scaled.rounded() - scaled).magnitude < 0.000_001 else { return nil }
        let halfSteps = Int(scaled.rounded())
        guard (2...10).contains(halfSteps) else { return nil }
        self.halfSteps = halfSteps
    }

    var value: Double { Double(halfSteps) / 2 }

    var anchor: String {
        switch halfSteps {
        case 2: return "Not for me"
        case 3: return "Mostly not for me"
        case 4: return "More misses than hits"
        case 5: return "Mixed"
        case 6: return "Enjoyed it"
        case 7: return "Really enjoyed it"
        case 8: return "Would order again"
        case 9: return "Memorable; I would seek it out"
        case 10: return "A personal favorite"
        default: return ""
        }
    }

    static var anchors: [(Double, String)] {
        (2...10).compactMap { halfSteps in
            let value = Double(halfSteps) / 2
            guard let rating = Self(value: value) else { return nil }
            return (value, rating.anchor)
        }
    }

    static func < (lhs: PersonalEnjoymentRating, rhs: PersonalEnjoymentRating) -> Bool {
        lhs.halfSteps < rhs.halfSteps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Double.self)
        guard let rating = Self(value: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Personal enjoyment must be from 1 through 5 in half-star steps."
            )
        }
        self = rating
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Drink identity

enum SensoryBeverageFamily: String, Codable, CaseIterable {
    case universal
    case espresso
    case brewedCoffee = "brewed_coffee"
    case milkCoffee = "milk_coffee"
    case matcha
    case matchaLatte = "matcha_latte"
    case hojichaLeaf = "hojicha_leaf"
    case hojichaPowder = "hojicha_powder"
    case hojichaLatte = "hojicha_latte"
    case greenTea = "green_tea"
    case blackTea = "black_tea"
    case whiteTea = "white_tea"
    case oolongTea = "oolong_tea"
    case herbalInfusion = "herbal_infusion"
    case milkTea = "milk_tea"
    case unknown

    var title: String {
        switch self {
        case .universal: return "Any drink"
        case .espresso: return "Espresso"
        case .brewedCoffee: return "Brewed coffee"
        case .milkCoffee: return "Milk coffee"
        case .matcha: return "Matcha"
        case .matchaLatte: return "Matcha latte"
        case .hojichaLeaf: return "Hojicha"
        case .hojichaPowder: return "Powdered hojicha"
        case .hojichaLatte: return "Hojicha latte"
        case .greenTea: return "Green tea"
        case .blackTea: return "Black tea"
        case .whiteTea: return "White tea"
        case .oolongTea: return "Oolong tea"
        case .herbalInfusion: return "Herbal infusion"
        case .milkTea: return "Milk tea"
        case .unknown: return "Drink"
        }
    }
}

enum SensoryPreparation: String, Codable, CaseIterable {
    case espresso
    case americano
    case pourOver = "pour_over"
    case drip
    case immersion
    case coldBrew = "cold_brew"
    case latte
    case cappuccino
    case flatWhite = "flat_white"
    case cortado
    case whiskedPowder = "whisked_powder"
    case steepedLeaf = "steeped_leaf"
    case milkTea = "milk_tea"
    case other
    case unknown

    var title: String {
        switch self {
        case .espresso: return "Espresso"
        case .americano: return "Americano"
        case .pourOver: return "Pour-over"
        case .drip: return "Drip"
        case .immersion: return "Immersion"
        case .coldBrew: return "Cold brew"
        case .latte: return "Latte"
        case .cappuccino: return "Cappuccino"
        case .flatWhite: return "Flat white"
        case .cortado: return "Cortado"
        case .whiskedPowder: return "Whisked powder"
        case .steepedLeaf: return "Steeped leaf"
        case .milkTea: return "Milk tea"
        case .other: return "Other preparation"
        case .unknown: return "Preparation not confirmed"
        }
    }
}

enum SensoryServingTemperature: String, Codable, CaseIterable {
    case hot
    case warm
    case iced
    case frozen
    case coldExtracted = "cold_extracted"
    case unknown

    var title: String {
        switch self {
        case .hot: return "Hot"
        case .warm: return "Warm"
        case .iced: return "Iced"
        case .frozen: return "Frozen"
        case .coldExtracted: return "Cold-extracted"
        case .unknown: return "Temperature not confirmed"
        }
    }
}

enum SensoryIdentityProvenance: String, Codable, CaseIterable {
    case user
    case localParser = "local_parser"
    case remoteParser = "remote_parser"
    case restoredSnapshot = "restored_snapshot"
    case fallback
}

enum SensoryDrinkModifierKind: String, Codable, CaseIterable {
    case milk
    case sweetener
    case flavor
    case foam
    case topping
    case dilution
    case other
}

struct SensoryDrinkModifier: Codable, Equatable, Identifiable {
    let id: String
    var kind: SensoryDrinkModifierKind
    var label: String
    var userConfirmed: Bool

    init(id: String, kind: SensoryDrinkModifierKind, label: String, userConfirmed: Bool = false) {
        self.id = id
        self.kind = kind
        self.label = label
        self.userConfirmed = userConfirmed
    }
}

struct SensoryDrinkIdentity: Codable, Equatable {
    var rawName: String
    var family: SensoryBeverageFamily
    var preparation: SensoryPreparation
    var temperature: SensoryServingTemperature
    var milk: String?
    var sweeteners: [String]
    var flavors: [String]
    var additions: [String]
    var modifiers: [SensoryDrinkModifier]
    var confidence: Double
    var provenance: SensoryIdentityProvenance
    var userConfirmed: Bool

    init(
        rawName: String,
        family: SensoryBeverageFamily,
        preparation: SensoryPreparation = .unknown,
        temperature: SensoryServingTemperature = .unknown,
        milk: String? = nil,
        sweeteners: [String] = [],
        flavors: [String] = [],
        additions: [String] = [],
        modifiers: [SensoryDrinkModifier] = [],
        confidence: Double = 0,
        provenance: SensoryIdentityProvenance = .user,
        userConfirmed: Bool = false
    ) {
        self.rawName = rawName
        self.family = family
        self.preparation = preparation
        self.temperature = temperature
        self.milk = milk
        self.sweeteners = sweeteners
        self.flavors = flavors
        self.additions = additions
        self.modifiers = modifiers
        self.confidence = min(max(confidence, 0), 1)
        self.provenance = provenance
        self.userConfirmed = userConfirmed
    }

    var displayName: String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? family.title : trimmed
    }

    var summary: String {
        var parts = [family.title]
        if preparation != .unknown { parts.append(preparation.title) }
        if temperature != .unknown { parts.append(temperature.title) }
        if let milk, !milk.isEmpty { parts.append(milk) }
        parts.append(contentsOf: flavors)
        return parts.joined(separator: " • ")
    }

    /// Scope used for learning. Confirmed preparation matters; individual syrups do not split history.
    var personalizationScopeID: String {
        if preparation != .unknown {
            return "\(family.rawValue).\(preparation.rawValue)"
        }
        return family.rawValue
    }
}

// MARK: - Versioned knowledge definitions

enum SensoryEvidenceClass: String, Codable, CaseIterable {
    case establishedScience = "established_science"
    case professionalConvention = "professional_convention"
    case productInterpretation = "product_interpretation"
    case openQuestion = "open_question"
}

enum SensoryEvidenceConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case exploratory
}

enum SensorySourceType: String, Codable, CaseIterable {
    case standard
    case professionalResource = "professional_resource"
    case peerReviewedStudy = "peer_reviewed_study"
    case peerReviewedReview = "peer_reviewed_review"
    case productResearch = "product_research"
}

struct SensorySourceReference: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let url: String
    let sourceType: SensorySourceType
    let evidenceClass: SensoryEvidenceClass
    let confidence: SensoryEvidenceConfidence
    let attribution: String
    let licenseNote: String
    let applicability: [String]
    let reviewDate: String
    let doNotInfer: String?
}

struct SensoryScaleAnchor: Codable, Equatable, Identifiable {
    let value: Int
    let label: String
    let anchor: String

    var id: Int { value }
}

struct SensoryScaleDefinition: Codable, Equatable, Identifiable {
    let id: String
    let version: Int
    let title: String
    let anchors: [SensoryScaleAnchor]
    let guidance: String?
}

struct SensoryChoiceDefinition: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let helper: String?
    let descriptorID: String?
}

enum SensoryApplicabilityField: String, Codable, CaseIterable {
    case family
    case preparation
    case temperature
    case modifierKind = "modifier_kind"
    case milk
    case flavor
    case addition
}

enum SensoryApplicabilityOperator: String, Codable, CaseIterable {
    case equals
    case oneOf = "one_of"
    case contains
    case exists
}

struct SensoryApplicabilityRule: Codable, Equatable {
    let field: SensoryApplicabilityField
    let operation: SensoryApplicabilityOperator
    let values: [String]
    let negated: Bool

    init(
        field: SensoryApplicabilityField,
        operation: SensoryApplicabilityOperator = .equals,
        values: [String],
        negated: Bool = false
    ) {
        self.field = field
        self.operation = operation
        self.values = values
        self.negated = negated
    }
}

struct SensoryCriterionDefinition: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let prompt: String
    let helper: String?
    let accessibilityLabel: String
    let dimension: SensoryDimension
    let stage: SensoryStage
    let measure: SensoryMeasureType
    let scaleID: String?
    let options: [SensoryChoiceDefinition]
    let descriptorRootIDs: [String]
    let depths: [TastingDepth]
    let applicability: [SensoryApplicabilityRule]
    let evidenceSourceIDs: [String]
    let order: Int

    var isIndependentOverallEnjoyment: Bool { measure == .overallEnjoyment }
}

struct SensoryDescriptorDefinition: Codable, Equatable, Identifiable {
    let id: String
    let parentID: String?
    let title: String
    let definition: String
    let synonyms: [String]
    let dimension: SensoryDimension
    let applicability: [SensoryBeverageFamily]
    let evidenceSourceIDs: [String]
    let evidenceClass: SensoryEvidenceClass
    let confidence: SensoryEvidenceConfidence
    let order: Int
}

enum SensoryPackKind: String, Codable, CaseIterable {
    case base
    case overlay
}

struct SensoryPackDefinition: Codable, Equatable, Identifiable {
    let id: String
    let kind: SensoryPackKind
    let title: String
    let family: SensoryBeverageFamily?
    let priority: Int
    let applicability: [SensoryApplicabilityRule]
    let criterionIDs: [String]
    let suppressedCriterionIDs: [String]
    let descriptorRootIDs: [String]
    let explanation: String
    let evidenceSourceIDs: [String]
}

struct SensoryKnowledgeBundle: Codable, Equatable {
    let bundleID: String
    let schemaVersion: Int
    let contentVersion: String
    let locale: String
    let publicationDate: String
    let reviewDate: String
    let sources: [SensorySourceReference]
    let scales: [SensoryScaleDefinition]
    let descriptors: [SensoryDescriptorDefinition]
    let criteria: [SensoryCriterionDefinition]
    let packs: [SensoryPackDefinition]

    func criterion(id: String) -> SensoryCriterionDefinition? {
        criteria.first { $0.id == id }
    }

    func descriptor(id: String) -> SensoryDescriptorDefinition? {
        descriptors.first { $0.id == id }
    }

    func descriptorChildren(of parentID: String) -> [SensoryDescriptorDefinition] {
        descriptors.filter { $0.parentID == parentID }.sorted { $0.order < $1.order }
    }

    func scale(id: String) -> SensoryScaleDefinition? {
        scales.first { $0.id == id }
    }
}

// MARK: - In-progress session and immutable snapshots

struct SensoryAIProvenance: Codable, Equatable {
    let model: String
    let modelVersion: String
    let confidence: Double
    let provenance: String
    let userConfirmed: Bool

    init(
        model: String,
        modelVersion: String,
        confidence: Double,
        provenance: String,
        userConfirmed: Bool
    ) {
        self.model = model
        self.modelVersion = modelVersion
        self.confidence = min(max(confidence, 0), 1)
        self.provenance = provenance
        self.userConfirmed = userConfirmed
    }
}

struct SensoryResponseDraft: Codable, Equatable, Identifiable {
    var id: UUID
    var criterionID: String
    var state: SensoryResponseState
    var descriptorIDs: [String]
    var choiceIDs: [String]
    var customText: String?
    var intensity: SensoryIntensityValue?
    var duration: SensoryDurationValue?
    var preference: SensoryPreference?
    var qualityImpression: SensoryQualityImpression?
    var confidence: SensoryConfidence?
    var suggestionOrigin: SensorySuggestionOrigin
    var sourcePackIDs: [String]
    var userConfirmed: Bool
    var aiProvenance: SensoryAIProvenance?
    var displayedOrder: Int

    init(
        id: UUID = UUID(),
        criterionID: String,
        state: SensoryResponseState = .notAsked,
        descriptorIDs: [String] = [],
        choiceIDs: [String] = [],
        customText: String? = nil,
        intensity: SensoryIntensityValue? = nil,
        duration: SensoryDurationValue? = nil,
        preference: SensoryPreference? = nil,
        qualityImpression: SensoryQualityImpression? = nil,
        confidence: SensoryConfidence? = nil,
        suggestionOrigin: SensorySuggestionOrigin = .basePack,
        sourcePackIDs: [String] = [],
        userConfirmed: Bool = false,
        aiProvenance: SensoryAIProvenance? = nil,
        displayedOrder: Int = 0
    ) {
        self.id = id
        self.criterionID = criterionID
        self.state = state
        self.descriptorIDs = descriptorIDs
        self.choiceIDs = choiceIDs
        self.customText = customText
        self.intensity = intensity
        self.duration = duration
        self.preference = preference
        self.qualityImpression = qualityImpression
        self.confidence = confidence
        self.suggestionOrigin = suggestionOrigin
        self.sourcePackIDs = sourcePackIDs
        self.userConfirmed = userConfirmed
        self.aiProvenance = aiProvenance
        self.displayedOrder = displayedOrder
    }
}

struct TastingLensSessionDraft: Codable, Equatable, Identifiable {
    var id: UUID
    var bundleID: String
    var bundleContentVersion: String
    var depth: TastingDepth
    var identity: SensoryDrinkIdentity
    var ownWords: String
    var responses: [SensoryResponseDraft]
    var personalEnjoyment: PersonalEnjoymentRating?
    var activePackIDs: [String]
    var startedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bundleID: String,
        bundleContentVersion: String,
        depth: TastingDepth,
        identity: SensoryDrinkIdentity,
        ownWords: String = "",
        responses: [SensoryResponseDraft] = [],
        personalEnjoyment: PersonalEnjoymentRating? = nil,
        activePackIDs: [String] = [],
        startedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bundleID = bundleID
        self.bundleContentVersion = bundleContentVersion
        self.depth = depth
        self.identity = identity
        self.ownWords = ownWords
        self.responses = responses
        self.personalEnjoyment = personalEnjoyment
        self.activePackIDs = activePackIDs
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    mutating func setResponse(_ response: SensoryResponseDraft, now: Date = .now) {
        if let index = responses.firstIndex(where: { $0.criterionID == response.criterionID }) {
            var updatedResponse = response
            updatedResponse.id = responses[index].id
            responses[index] = updatedResponse
        } else {
            responses.append(response)
        }
        updatedAt = now
    }

    func response(for criterionID: String) -> SensoryResponseDraft? {
        responses.first { $0.criterionID == criterionID }
    }
}

struct SensoryDescriptorSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let displayedTitle: String
    let displayedPath: [String]
}

struct SensoryChoiceSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let displayedLabel: String
}

struct SensoryScaleAnchorSnapshot: Codable, Equatable, Identifiable {
    let value: Int
    let displayedLabel: String
    let displayedAnchor: String

    var id: Int { value }
}

struct SipSensoryResponseSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let criterionID: String
    let displayedCriterionTitle: String
    let dimension: SensoryDimension
    let measure: SensoryMeasureType
    let state: SensoryResponseState
    let descriptors: [SensoryDescriptorSnapshot]
    let selectedChoices: [SensoryChoiceSnapshot]
    let customText: String?
    let intensity: SensoryIntensityValue?
    let duration: SensoryDurationValue?
    let preference: SensoryPreference?
    let qualityImpression: SensoryQualityImpression?
    let confidence: SensoryConfidence?
    let scaleID: String?
    let scaleVersion: Int?
    let displayedScaleAnchors: [SensoryScaleAnchorSnapshot]
    let bundleID: String
    let bundleContentVersion: String
    let sourcePackIDs: [String]
    let suggestionOrigin: SensorySuggestionOrigin
    let displayedOrder: Int
    let aiProvenance: SensoryAIProvenance?
    let userConfirmed: Bool

    var selectedChoiceIDs: [String] { selectedChoices.map(\.id) }
}

struct SipSensorySnapshot: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    let id: UUID
    let schemaVersion: Int
    let bundleID: String
    let bundleContentVersion: String
    let identity: SensoryDrinkIdentity
    let personalizationScopeID: String
    let depth: TastingDepth
    let ownWords: String
    let responses: [SipSensoryResponseSnapshot]
    /// The user's independent rating. It is never calculated from `responses`.
    let personalEnjoyment: PersonalEnjoymentRating?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = SipSensorySnapshot.currentSchemaVersion,
        bundleID: String,
        bundleContentVersion: String,
        identity: SensoryDrinkIdentity,
        personalizationScopeID: String? = nil,
        depth: TastingDepth,
        ownWords: String,
        responses: [SipSensoryResponseSnapshot],
        personalEnjoyment: PersonalEnjoymentRating?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.bundleID = bundleID
        self.bundleContentVersion = bundleContentVersion
        self.identity = identity
        self.personalizationScopeID = personalizationScopeID ?? identity.personalizationScopeID
        self.depth = depth
        self.ownWords = ownWords
        self.responses = responses.sorted { $0.displayedOrder < $1.displayedOrder }
        self.personalEnjoyment = personalEnjoyment
        self.createdAt = createdAt
    }
}

// MARK: - Preferences and transparent learning

enum SensorySuggestionDismissalReason: String, Codable, CaseIterable {
    case notUseful = "not_useful"
    case selectedByMistake = "selected_by_mistake"
    case notRelevant = "not_relevant"
    case other
}

struct SensorySuggestionDismissal: Codable, Equatable, Identifiable {
    let id: UUID
    let targetID: String
    let scopeID: String
    let snapshotID: UUID?
    let reason: SensorySuggestionDismissalReason
    let createdAt: Date

    init(
        id: UUID = UUID(),
        targetID: String,
        scopeID: String,
        snapshotID: UUID? = nil,
        reason: SensorySuggestionDismissalReason,
        createdAt: Date = .now
    ) {
        self.id = id
        self.targetID = targetID
        self.scopeID = scopeID
        self.snapshotID = snapshotID
        self.reason = reason
        self.createdAt = createdAt
    }
}

struct TastingLensUserPreferences: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var userID: UUID
    var defaultDepth: TastingDepth
    var pinnedCriterionIDsByScope: [String: [String]]
    var dismissals: [SensorySuggestionDismissal]
    var customCriteria: [SensoryCriterionDefinition]
    var updatedAt: Date

    init(
        schemaVersion: Int = TastingLensUserPreferences.currentSchemaVersion,
        userID: UUID,
        defaultDepth: TastingDepth = .guided,
        pinnedCriterionIDsByScope: [String: [String]] = [:],
        dismissals: [SensorySuggestionDismissal] = [],
        customCriteria: [SensoryCriterionDefinition] = [],
        updatedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.userID = userID
        self.defaultDepth = defaultDepth
        self.pinnedCriterionIDsByScope = pinnedCriterionIDsByScope
        self.dismissals = dismissals
        self.customCriteria = customCriteria
        self.updatedAt = updatedAt
    }

    func pinnedCriterionIDs(for scopeID: String) -> [String] {
        pinnedCriterionIDsByScope[scopeID] ?? []
    }

    /// Hiding a criterion changes future question selection. A dismissed learned
    /// pattern is intentionally separate so "not useful" never removes the
    /// underlying question from the user's Lens.
    func hidesCriterion(targetID: String, scopeID: String) -> Bool {
        dismissals.contains {
            $0.targetID == targetID && $0.scopeID == scopeID &&
                $0.reason == .notRelevant && $0.snapshotID == nil
        }
    }

    func suppressesPattern(targetID: String, scopeID: String) -> Bool {
        dismissals.contains {
            $0.targetID == targetID && $0.scopeID == scopeID &&
                ($0.reason == .notUseful || $0.reason == .notRelevant) && $0.snapshotID == nil
        }
    }
}

enum LearnedSensoryPatternTarget: String, Codable, CaseIterable {
    case criterion
    case descriptor
}

struct SensoryPatternCount: Codable, Equatable {
    let learning: Int
    let maybe: Int
    let sure: Int
}

struct SensoryPreferenceCount: Codable, Equatable {
    let notForMe: Int
    let neutral: Int
    let liked: Int
}

struct SensoryIntensitySummary: Codable, Equatable {
    let scale: SensoryIntensityScale
    let levelCounts: [Int: Int]
    let medianLevel: Int
}

enum SensoryEnjoymentAssociationDirection: String, Codable, CaseIterable {
    case higher
    case similar
    case lower
}

struct SensoryEnjoymentAssociation: Codable, Equatable {
    let observedSupportCount: Int
    let comparisonCount: Int
    let averageWhenObserved: Double
    let averageWhenNotObserved: Double
    let difference: Double
    let direction: SensoryEnjoymentAssociationDirection
    let explanation: String
}

struct LearnedSensoryPattern: Codable, Equatable, Identifiable {
    let id: String
    let userID: UUID
    let scopeID: String
    let targetType: LearnedSensoryPatternTarget
    let targetID: String
    let title: String
    let supportCount: Int
    let totalCount: Int
    let spontaneousSupportCount: Int
    let confidenceCounts: SensoryPatternCount
    let intensity: SensoryIntensitySummary?
    let preferences: SensoryPreferenceCount
    let enjoymentAssociation: SensoryEnjoymentAssociation?
    /// A deterministic prompt-order adjustment, never a beverage score.
    let rankBoost: Int
    let evidenceSnapshotIDs: [UUID]
    let evidenceSummary: String
    let generatedAt: Date
}

struct RankedSensoryCriterion: Equatable, Identifiable {
    let criterion: SensoryCriterionDefinition
    let rank: Int
    let origin: SensorySuggestionOrigin
    let explanation: String
    /// Exact packs that supplied this criterion, frozen with each response.
    /// Custom criteria intentionally carry an empty list.
    let sourcePackIDs: [String]

    var id: String { criterion.id }
}

struct TastingLensSelection: Equatable {
    let identity: SensoryDrinkIdentity
    let basePack: SensoryPackDefinition
    let overlays: [SensoryPackDefinition]
    let orderedCriteria: [RankedSensoryCriterion]
    let descriptors: [SensoryDescriptorDefinition]
    let usedUniversalFallback: Bool
    let explanations: [String]

    var criteria: [SensoryCriterionDefinition] { orderedCriteria.map(\.criterion) }
    var activePackIDs: [String] {
        var seen = Set<String>()
        return ([basePack.id] + overlays.map(\.id) + orderedCriteria.flatMap(\.sourcePackIDs))
            .filter { seen.insert($0).inserted }
    }
}
