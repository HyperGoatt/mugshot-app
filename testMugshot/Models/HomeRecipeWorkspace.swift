import Foundation

enum HomeRecipeTemplate: String, Codable, CaseIterable, Identifiable, Sendable {
    case coffee, component, drink, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .coffee: return "Coffee preparation"
        case .component: return "Ingredient or component"
        case .drink: return "Complete drink"
        case .custom: return "Start blank"
        }
    }
    var symbol: String {
        switch self {
        case .coffee: return "cup.and.saucer"
        case .component: return "drop"
        case .drink: return "mug"
        case .custom: return "square.and.pencil"
        }
    }
}

enum HomeRecipeCalculation: String, Codable, CaseIterable, Sendable {
    case ratio, output
    var title: String { self == .ratio ? "Set by ratio" : "Set by yield" }
}

struct HomeRecipeTargets: Codable, Equatable, Sendable {
    var dose: Double?
    var ratio: Double?
    var output: Double?
    var calculation: HomeRecipeCalculation = .ratio
    var seconds: Double?
    var temperature: Double?
    var grind: String = ""
    var preinfusion: Double?
    var pressure: Double?
    var steepSeconds: Double?
    var dilution: String = ""

    var resolvedOutput: Double? {
        if calculation == .output { return output }
        guard let dose, dose > 0, let ratio, ratio > 0 else { return nil }
        return dose * ratio
    }
    var resolvedRatio: Double? {
        if calculation == .ratio { return ratio }
        guard let dose, dose > 0, let output, output > 0 else { return nil }
        return output / dose
    }
    var isValid: Bool {
        [dose, ratio, output, seconds, preinfusion, pressure, steepSeconds]
            .compactMap { $0 }.allSatisfy { $0.isFinite && $0 > 0 }
            && (temperature.map { $0.isFinite && $0 > -273.15 } ?? true)
    }
}

struct HomeRecipeReference: Codable, Equatable, Hashable, Sendable {
    var recipeID: UUID
    var versionID: UUID
}

struct HomeRecipePostAttachment: Codable, Equatable, Identifiable, Sendable {
    let versionID: UUID
    let audience: String
    let acknowledgesSharing: Bool
    var id: UUID { versionID }
}

struct HomeSavedRecipeReference: Codable, Equatable, Identifiable, Sendable {
    let recipeID: UUID
    let versionID: UUID
    let name: String
    var id: UUID { versionID }
}

struct HomeRecipeIngredient: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name = ""
    var amount: Double?
    var unit = "g"
    var recipe: HomeRecipeReference?
}

enum HomeWaterTargetMode: String, Codable, CaseIterable, Sendable {
    case cumulative, incremental
    var title: String { self == .cumulative ? "Pour to this total" : "Add this much" }
}

struct HomePreparationStep: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var instruction = ""
    var startSeconds: Double?
    var waitSeconds: Double?
    var waterGrams: Double?
    var waterMode: HomeWaterTargetMode = .cumulative
}

enum HomeCustomFieldKind: String, Codable, CaseIterable, Sendable {
    case text, number, duration, choice
    var title: String {
        switch self {
        case .text: return "Text"
        case .number: return "Number + unit"
        case .duration: return "Duration"
        case .choice: return "Choice"
        }
    }
}

struct HomeCustomField: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var label = ""
    var kind: HomeCustomFieldKind = .text
    var value = ""
    var unit = ""
    var choices: [String] = []
    var isVisible = true
}

enum HomeRecipeMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case dose, output, seconds, temperature, grind, preinfusion, pressure, steepSeconds, dilution
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dose: "Coffee dose (g)"
        case .output: "Yield or water (g)"
        case .seconds: "Target time (seconds)"
        case .temperature: "Temperature (°C)"
        case .grind: "Grinder setting"
        case .preinfusion: "Preinfusion (seconds)"
        case .pressure: "Pressure (bar)"
        case .steepSeconds: "Steep duration (seconds)"
        case .dilution: "Serving dilution"
        }
    }
    var numericKeyPath: WritableKeyPath<HomeRecipeTargets, Double?>? {
        switch self {
        case .dose: \.dose
        case .output: \.output
        case .seconds: \.seconds
        case .temperature: \.temperature
        case .preinfusion: \.preinfusion
        case .pressure: \.pressure
        case .steepSeconds: \.steepSeconds
        case .grind, .dilution: nil
        }
    }
}

struct HomeRecipeMetricConfiguration: Identifiable, Codable, Equatable, Sendable {
    var metric: HomeRecipeMetric
    var label: String
    var isVisible = true
    var id: String { metric.rawValue }
}

/// A reusable blueprint. Feedback and private attempt media never belong here.
struct HomeRecipeContent: Codable, Equatable, Sendable {
    var name = ""
    var template: HomeRecipeTemplate = .custom
    var method: HomeBrewMethod = .other
    var targets = HomeRecipeTargets()
    var ingredients: [HomeRecipeIngredient] = []
    var steps: [HomePreparationStep] = []
    var fields: [HomeCustomField] = []
    var hiddenFields: Set<String> = []
    var servings: Double = 1
    var yieldDescription = ""
    var sourceURL = ""
    var creatorCredit = ""
    var sourceVersionID: UUID?
    var tags: [String] = []
    var notes = ""
    var coffee: CoffeeBagSnapshot?
    var equipment: [EquipmentSnapshot] = []
    /// Retained without guessing whether old measurements were targets or actuals.
    var legacyDetails: BrewDetails?
    var sourceReuseAllowed: Bool?
    var metricConfiguration: [HomeRecipeMetricConfiguration]?

    var configuredMetrics: [HomeRecipeMetricConfiguration] {
        metricConfiguration ?? HomeRecipeMetric.allCases.map {
            HomeRecipeMetricConfiguration(metric: $0, label: $0.label,
                isVisible: !hiddenFields.contains($0.rawValue))
        }
    }

    var isActionable: Bool {
        !ingredients.isEmpty || steps.contains { !$0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || targets.dose != nil || targets.steepSeconds != nil
    }
    var validationMessage: String? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if sourceVersionID != nil, sourceReuseAllowed == false { return "This source does not permit an editable copy. You can still log a make from the original." }
        guard !clean.isEmpty, clean.count <= 120 else { return "Enter a recipe name of up to 120 characters." }
        guard targets.isValid, servings.isFinite, servings > 0 else { return "Amounts and durations must be positive numbers." }
        guard ingredients.allSatisfy({ $0.amount.map { $0.isFinite && $0 > 0 } ?? true }) else { return "Ingredient amounts must be positive." }
        guard steps.allSatisfy({ step in
            [step.startSeconds, step.waitSeconds, step.waterGrams].compactMap { $0 }.allSatisfy { $0.isFinite && $0 >= 0 }
        }) else { return "Step amounts and timing cannot be negative." }
        guard fields.allSatisfy({ field in
            if field.value.isEmpty { return true }
            switch field.kind {
            case .text: return true
            case .choice: return field.choices.contains(field.value)
            case .number, .duration:
                guard let value = Double(field.value), value.isFinite else { return false }
                return field.kind != .duration || value >= 0
            }
        }) else { return "Check custom numbers, durations, and choices." }
        return nil
    }
    var searchText: String {
        ([name, method.title, creatorCredit, coffee?.displayName ?? ""] + tags + equipment.map(\.displayName))
            .joined(separator: " ").lowercased()
    }
    var summary: String {
        if template == .coffee {
            return [targets.dose.map { "\(Self.number($0)) g coffee" },
                    targets.resolvedOutput.map { "\(Self.number($0)) g \(method == .espresso ? "yield" : "water")" },
                    targets.seconds.map { "\(Self.number($0)) sec" },
                    targets.steepSeconds.map { "\(Self.number($0 / 3600)) hr" }]
                .compactMap { $0 }.joined(separator: " · ")
        }
        return [yieldDescription.isEmpty ? "\(Self.number(servings)) serving(s)" : yieldDescription,
                "\(ingredients.count) ingredients"].joined(separator: " · ")
    }
    func cumulativeWater(through index: Int) -> Double? {
        guard steps.indices.contains(index) else { return nil }
        var total: Double?
        for step in steps.prefix(index + 1) {
            guard let water = step.waterGrams else { continue }
            total = step.waterMode == .cumulative ? water : (total ?? 0) + water
        }
        return total
    }
    func scaled(by factor: Double) -> Self {
        guard factor.isFinite, factor > 0 else { return self }
        var copy = self
        copy.servings *= factor
        copy.targets.dose = targets.dose.map { $0 * factor }
        copy.targets.output = targets.output.map { $0 * factor }
        copy.ingredients = ingredients.map { var item = $0; item.amount = item.amount.map { $0 * factor }; return item }
        copy.steps = steps.map { var step = $0; step.waterGrams = step.waterGrams.map { $0 * factor }; return step }
        return copy
    }
    static func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }
}

struct HomeRecipeVersion: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var number = 1
    var createdAt = Date()
    var content: HomeRecipeContent
}

struct HomeRecipeRecord: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var versions: [HomeRecipeVersion]
    var isPinned = false
    var isArchived = false
    var favoriteAttemptID: UUID?
    var nextTimeNote = ""
    var lastUsedAt: Date?
    var current: HomeRecipeVersion? { versions.last }
}

struct HomeAttemptActuals: Codable, Equatable, Sendable {
    var dose: Double?
    var output: Double?
    var seconds: Double?
    var temperature: Double?
    var grind = ""
    var batchMilliliters: Double?
    var servingMilliliters: Double?
    var dilution = ""
}

/// Targets are frozen context; absent actuals are always unknown.
struct HomeAttemptRecord: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var createdAt = Date()
    var name = ""
    var recipe: HomeRecipeReference?
    var targets: HomeRecipeContent?
    var preparation: HomeRecipeContent?
    var actuals = HomeAttemptActuals()
    var rating: Double?
    var reaction = ""
    var privateNote = ""
    var nextTimeNote = ""
    var makeAgain: HomeMakeAgain?
    var batchID: UUID?
    var batchSourceAttemptID: UUID?
    var photoNames: [String] = []
    var savedAt: Date?
    var publicationDraftID: UUID?

    static func fresh(from recipe: HomeRecipeRecord?, setup: HomeRecipeContent? = nil) -> Self {
        let version = recipe?.current
        return Self(name: setup?.name ?? version?.content.name ?? "",
                    recipe: recipe.flatMap { record in version.map { HomeRecipeReference(recipeID: record.id, versionID: $0.id) } },
                    targets: version?.content, preparation: setup ?? version?.content)
    }
    var recipeCandidate: HomeRecipeContent {
        var content = preparation ?? HomeRecipeContent()
        content.name = name
        if let dose = actuals.dose { content.targets.dose = dose }
        if let output = actuals.output { content.targets.output = output; content.targets.calculation = .output }
        if let seconds = actuals.seconds { content.targets.seconds = seconds }
        if let temperature = actuals.temperature { content.targets.temperature = temperature }
        if !actuals.grind.isEmpty { content.targets.grind = actuals.grind }
        return content
    }
}

struct HomePreparationSession: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var attempt: HomeAttemptRecord
    var startedAt = Date()
    var stepIndex = 0
    var completedIngredientIDs: Set<UUID> = []
    var preparedRecipeIDs: Set<UUID> = []
    /// Key readiness by immutable version, not identity: two linked versions can
    /// have different preparation. Optional for decoding earlier workspaces.
    var linkedPreparations: [HomeLinkedPreparationProgress]?
    var reminderEnabled = false
    var finishedAt: Date?
    var timerStartedAt: Date?
    var readyAt: Date? { attempt.preparation?.targets.steepSeconds.map { startedAt.addingTimeInterval($0) } }
    func elapsed(at date: Date) -> TimeInterval { max(0, (finishedAt ?? date).timeIntervalSince(startedAt)) }
}

struct HomeLinkedPreparationProgress: Identifiable, Codable, Equatable, Sendable {
    var reference: HomeRecipeReference
    var stepIndex = 0
    var startedAt: Date?
    var completedAt: Date?
    var id: UUID { reference.versionID }
}

struct HomeRecipeEditorDraft: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var recipeID: UUID?
    var baseVersionID: UUID?
    var content = HomeRecipeContent()
}

struct HomeRecipeWorkspace: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var recipes: [HomeRecipeRecord] = []
    var attempts: [HomeAttemptRecord] = []
    var sessions: [HomePreparationSession] = []
    var recipeDrafts: [HomeRecipeEditorDraft] = []
    var attemptDrafts: [HomeAttemptRecord] = []
    var remoteRevision = 0
    var pendingOperationID: UUID?
    var savedReferences: [HomeSavedRecipeReference]?

    func version(_ reference: HomeRecipeReference) -> HomeRecipeVersion? {
        recipes.first { $0.id == reference.recipeID }?.versions.first { $0.id == reference.versionID }
    }
    var usuals: [HomeRecipeRecord] {
        recipes.filter { !$0.isArchived && ($0.isPinned || $0.lastUsedAt != nil) }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast)
        }
    }
    func wouldCreateCycle(recipeID: UUID, content: HomeRecipeContent) -> Bool {
        func visit(_ id: UUID, seen: Set<UUID>) -> Bool {
            if id == recipeID { return true }
            if seen.contains(id) { return false }
            let next = seen.union([id])
            return recipes.first { $0.id == id }?.current?.content.ingredients
                .compactMap(\.recipe).contains { visit($0.recipeID, seen: next) } ?? false
        }
        return content.ingredients.compactMap(\.recipe).contains { visit($0.recipeID, seen: []) }
    }
}

enum HomeRecipeWorkspaceError: LocalizedError {
    case invalid(String), conflict, unavailableReference, corruptData
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .conflict: return "This recipe library changed on another device. Your edits are safe. Review both copies before continuing."
        case .unavailableReference: return "A linked recipe version is unavailable. Choose another recipe or remove the link."
        case .corruptData: return "Your Home library could not be read. The original file has been preserved."
        }
    }
}
