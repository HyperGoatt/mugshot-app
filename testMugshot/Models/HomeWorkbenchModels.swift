import Foundation

enum CoffeeBagStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case unopened
    case resting
    case open
    case frozen
    case finished
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unopened: return "Unopened"
        case .resting: return "Resting"
        case .open: return "Open"
        case .frozen: return "Frozen"
        case .finished: return "Finished"
        case .archived: return "Archived"
        }
    }

    var isCurrent: Bool {
        self == .unopened || self == .resting || self == .open || self == .frozen
    }
}

/// The owner-managed coffee record. Inventory state and private media never
/// enter the social brew snapshot stored on a visit.
struct CoffeeBag: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var ownerUserID: UUID?
    var roaster: String
    var name: String
    var producer: String
    var origin: String
    var process: String
    var variety: String
    var roastLevel: String
    var roastDate: Date?
    var tastingNotes: String
    var startingWeightGrams: Double?
    var remainingWeightGrams: Double?
    var status: CoffeeBagStatus
    var openedAt: Date?
    var frozenAt: Date?
    var privatePhotoPath: String?
    var localPhotoPath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerUserID: UUID? = nil,
        roaster: String = "",
        name: String = "",
        producer: String = "",
        origin: String = "",
        process: String = "",
        variety: String = "",
        roastLevel: String = "",
        roastDate: Date? = nil,
        tastingNotes: String = "",
        startingWeightGrams: Double? = nil,
        remainingWeightGrams: Double? = nil,
        status: CoffeeBagStatus = .open,
        openedAt: Date? = nil,
        frozenAt: Date? = nil,
        privatePhotoPath: String? = nil,
        localPhotoPath: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.roaster = roaster
        self.name = name
        self.producer = producer
        self.origin = origin
        self.process = process
        self.variety = variety
        self.roastLevel = roastLevel
        self.roastDate = roastDate
        self.tastingNotes = tastingNotes
        self.startingWeightGrams = startingWeightGrams
        self.remainingWeightGrams = remainingWeightGrams
        self.status = status
        self.openedAt = openedAt
        self.frozenAt = frozenAt
        self.privatePhotoPath = privatePhotoPath
        self.localPhotoPath = localPhotoPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayName: String {
        name.remoteTrimmedNonEmpty
            ?? roaster.remoteTrimmedNonEmpty
            ?? "Untitled coffee"
    }

    var safeSnapshot: CoffeeBagSnapshot {
        CoffeeBagSnapshot(
            roaster: roaster.remoteTrimmedNonEmpty,
            name: name.remoteTrimmedNonEmpty,
            producer: producer.remoteTrimmedNonEmpty,
            origin: origin.remoteTrimmedNonEmpty,
            process: process.remoteTrimmedNonEmpty,
            variety: variety.remoteTrimmedNonEmpty,
            roastLevel: roastLevel.remoteTrimmedNonEmpty,
            roastDate: roastDate,
            tastingNotes: tastingNotes.remoteTrimmedNonEmpty
        )
    }
}

/// A deliberately safe, immutable identity snapshot. It excludes owner IDs,
/// inventory state, lifecycle dates, OCR text, and private storage paths.
struct CoffeeBagSnapshot: Codable, Equatable, Sendable {
    var roaster: String?
    var name: String?
    var producer: String?
    var origin: String?
    var process: String?
    var variety: String?
    var roastLevel: String?
    var roastDate: Date?
    var tastingNotes: String?

    var displayName: String? {
        let parts = [roaster?.remoteTrimmedNonEmpty, name?.remoteTrimmedNonEmpty]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum EquipmentRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case brewer
    case grinder
    case espressoMachine = "espresso_machine"
    case kettle
    case filter
    case scale
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brewer: return "Brewer"
        case .grinder: return "Grinder"
        case .espressoMachine: return "Espresso machine"
        case .kettle: return "Kettle"
        case .filter: return "Filter"
        case .scale: return "Scale"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .brewer: return "cup.and.heat.waves.fill"
        case .grinder: return "gearshape.2.fill"
        case .espressoMachine: return "mug.fill"
        case .kettle: return "drop.degreesign.fill"
        case .filter: return "line.3.horizontal.decrease"
        case .scale: return "scalemass.fill"
        case .other: return "wrench.and.screwdriver.fill"
        }
    }
}

struct EquipmentProfile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var ownerUserID: UUID?
    var role: EquipmentRole
    var nickname: String
    var brand: String
    var model: String
    var notes: String
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerUserID: UUID? = nil,
        role: EquipmentRole = .brewer,
        nickname: String = "",
        brand: String = "",
        model: String = "",
        notes: String = "",
        archivedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.role = role
        self.nickname = nickname
        self.brand = brand
        self.model = model
        self.notes = notes
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayName: String {
        nickname.remoteTrimmedNonEmpty
            ?? [brand.remoteTrimmedNonEmpty, model.remoteTrimmedNonEmpty]
                .compactMap { $0 }
                .joined(separator: " ")
                .remoteTrimmedNonEmpty
            ?? role.title
    }

    var snapshot: EquipmentSnapshot {
        EquipmentSnapshot(
            role: role,
            displayName: displayName,
            brand: brand.remoteTrimmedNonEmpty,
            model: model.remoteTrimmedNonEmpty
        )
    }
}

struct EquipmentSnapshot: Codable, Equatable, Identifiable, Sendable {
    var role: EquipmentRole
    var displayName: String
    var brand: String?
    var model: String?

    var id: String { "\(role.rawValue)|\(displayName.lowercased())" }
}

enum HomeBrewMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case espresso
    case pourOver = "pour_over"
    case aeroPress = "aeropress"
    case frenchPress = "french_press"
    case immersion
    case mokaPot = "moka_pot"
    case coldBrew = "cold_brew"
    case batch
    case pod
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .espresso: return "Espresso"
        case .pourOver: return "Pour-over"
        case .aeroPress: return "AeroPress"
        case .frenchPress: return "French press"
        case .immersion: return "Immersion"
        case .mokaPot: return "Moka pot"
        case .coldBrew: return "Cold brew"
        case .batch: return "Batch"
        case .pod: return "Pod"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .espresso: return "cup.and.saucer.fill"
        case .pourOver: return "drop.triangle.fill"
        case .aeroPress, .frenchPress, .immersion: return "arrow.down.to.line.compact"
        case .mokaPot: return "flame.fill"
        case .coldBrew: return "snowflake"
        case .batch: return "mug.fill"
        case .pod: return "capsule.fill"
        case .other: return "ellipsis"
        }
    }

    var usesYield: Bool { self == .espresso }

    var detailFields: Set<HomeBrewDetailField> {
        switch self {
        case .espresso:
            return [.preinfusion, .pressure, .pressureFlowNotes]
        case .pourOver:
            return [.bloom, .pourPattern, .pourStages]
        case .aeroPress, .frenchPress, .immersion:
            return [.steep, .press, .agitation]
        case .mokaPot:
            return [.heat]
        case .coldBrew:
            return [.coldBrewSteep, .customNotes]
        case .batch, .pod, .other:
            return [.customNotes]
        }
    }

    init(storedValue: String?) {
        let normalized = storedValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        switch normalized {
        case "espresso": self = .espresso
        case "pour over", "pourover", "v60", "chemex": self = .pourOver
        case "aeropress", "aero press": self = .aeroPress
        case "french press": self = .frenchPress
        case "immersion": self = .immersion
        case "moka pot", "moka": self = .mokaPot
        case "cold brew": self = .coldBrew
        case "batch", "batch brew": self = .batch
        case "pod", "capsule": self = .pod
        default: self = .other
        }
    }
}

enum HomeBrewDetailField: String, Codable, Hashable, Sendable {
    case preinfusion
    case pressure
    case pressureFlowNotes = "pressure_flow_notes"
    case bloom
    case pourPattern = "pour_pattern"
    case pourStages = "pour_stages"
    case steep
    case press
    case agitation
    case heat
    case coldBrewSteep = "cold_brew_steep"
    case customNotes = "custom_notes"
}

/// Optional method-specific detail. Common measurements remain in
/// `BrewDetails` so older visits and recipe projections keep decoding.
struct HomeMethodDetails: Codable, Equatable, Sendable {
    var waterGrams: Double?
    var bloomGrams: Double?
    var bloomSeconds: Int?
    var preinfusionSeconds: Int?
    var pressureBars: Double?
    var pressureFlowNotes: String?
    var steepSeconds: Int?
    var coldBrewSteepHours: Double?
    var pressSeconds: Int?
    var pourPattern: String?
    var agitationNotes: String?
    var heatNotes: String?
    var customNotes: String?

    static let empty = HomeMethodDetails()

    var hasData: Bool {
        waterGrams != nil || bloomGrams != nil || bloomSeconds != nil ||
            preinfusionSeconds != nil || pressureBars != nil ||
            pressureFlowNotes?.remoteTrimmedNonEmpty != nil || steepSeconds != nil ||
            coldBrewSteepHours != nil ||
            pressSeconds != nil || pourPattern?.remoteTrimmedNonEmpty != nil ||
            agitationNotes?.remoteTrimmedNonEmpty != nil || heatNotes?.remoteTrimmedNonEmpty != nil ||
            customNotes?.remoteTrimmedNonEmpty != nil
    }
}

/// Canonical metric values used by comparisons and future unit-aware entry.
/// Storage remains grams, Celsius, and seconds even if display units change.
struct HomeBrewMetrics: Codable, Equatable, Sendable {
    enum WeightUnit: Sendable { case grams, ounces }
    enum TemperatureUnit: Sendable { case celsius, fahrenheit }
    enum DurationUnit: Sendable { case seconds, minutes, hours }

    var doseGrams: Double?
    var waterGrams: Double?
    var yieldGrams: Double?
    var temperatureCelsius: Double?
    var totalTimeSeconds: Int?

    var ratio: Double? {
        guard let doseGrams, doseGrams > 0,
              let output = yieldGrams ?? waterGrams,
              output > 0 else { return nil }
        return output / doseGrams
    }

    static func grams(_ value: Double, from unit: WeightUnit) -> Double {
        switch unit {
        case .grams: return value
        case .ounces: return value * 28.349_523_125
        }
    }

    static func celsius(_ value: Double, from unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius: return value
        case .fahrenheit: return (value - 32) * 5 / 9
        }
    }

    static func seconds(_ value: Double, from unit: DurationUnit) -> Int {
        let multiplier: Double
        switch unit {
        case .seconds: multiplier = 1
        case .minutes: multiplier = 60
        case .hours: multiplier = 3_600
        }
        return Int((value * multiplier).rounded())
    }
}

struct HomeBrewSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var capturedAt: Date
    var drinkName: String
    var brewMethod: String
    var equipment: String
    var brewDetails: BrewDetails
    var makeAgain: HomeMakeAgain?

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        drinkName: String,
        brewMethod: String,
        equipment: String,
        brewDetails: BrewDetails,
        makeAgain: HomeMakeAgain? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.drinkName = drinkName
        self.brewMethod = brewMethod
        self.equipment = equipment
        self.brewDetails = brewDetails
        self.makeAgain = makeAgain
    }

    var title: String {
        brewDetails.recipeName?.remoteTrimmedNonEmpty
            ?? brewDetails.coffeeBag?.displayName
            ?? drinkName.remoteTrimmedNonEmpty
            ?? "Recent setup"
    }

    var subtitle: String {
        [brewMethod.remoteTrimmedNonEmpty, brewDetails.extractionSummary]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

struct HomeBrewDelta: Identifiable, Equatable, Sendable {
    let key: String
    let label: String
    let currentValue: String
    let previousValue: String

    var id: String { key }
}

struct HomeBrewComparison: Equatable, Sendable {
    let deltas: [HomeBrewDelta]

    static func compare(current: HomeBrewSnapshot, with previous: HomeBrewSnapshot?) -> Self {
        guard let previous else { return HomeBrewComparison(deltas: []) }
        var result: [HomeBrewDelta] = []

        appendText(
            key: "method",
            label: "Method",
            current: current.brewMethod,
            previous: previous.brewMethod,
            to: &result
        )
        appendNumber(
            key: "dose",
            label: "Dose",
            current: current.brewDetails.doseGrams,
            previous: previous.brewDetails.doseGrams,
            suffix: "g",
            to: &result
        )
        appendNumber(
            key: "water",
            label: "Water",
            current: current.brewDetails.homeMethodDetails?.waterGrams,
            previous: previous.brewDetails.homeMethodDetails?.waterGrams,
            suffix: "g",
            to: &result
        )
        appendNumber(
            key: "yield",
            label: "Yield",
            current: current.brewDetails.yieldGrams,
            previous: previous.brewDetails.yieldGrams,
            suffix: "g",
            to: &result
        )
        appendText(
            key: "grind",
            label: "Grind",
            current: current.brewDetails.grindSetting,
            previous: previous.brewDetails.grindSetting,
            to: &result
        )
        appendNumber(
            key: "temperature",
            label: "Water",
            current: current.brewDetails.waterTemperatureCelsius,
            previous: previous.brewDetails.waterTemperatureCelsius,
            suffix: "°C",
            to: &result
        )
        appendNumber(
            key: "preinfusion",
            label: "Preinfusion",
            current: current.brewDetails.homeMethodDetails?.preinfusionSeconds.map(Double.init),
            previous: previous.brewDetails.homeMethodDetails?.preinfusionSeconds.map(Double.init),
            suffix: "s",
            to: &result
        )
        appendNumber(
            key: "pressure",
            label: "Pressure",
            current: current.brewDetails.homeMethodDetails?.pressureBars,
            previous: previous.brewDetails.homeMethodDetails?.pressureBars,
            suffix: "bar",
            to: &result
        )
        appendNumber(
            key: "bloom",
            label: "Bloom",
            current: current.brewDetails.homeMethodDetails?.bloomSeconds.map(Double.init),
            previous: previous.brewDetails.homeMethodDetails?.bloomSeconds.map(Double.init),
            suffix: "s",
            to: &result
        )
        appendNumber(
            key: "steep",
            label: "Steep",
            current: current.brewDetails.homeMethodDetails?.steepSeconds.map(Double.init),
            previous: previous.brewDetails.homeMethodDetails?.steepSeconds.map(Double.init),
            suffix: "s",
            to: &result
        )
        appendNumber(
            key: "cold-steep",
            label: "Steep",
            current: current.brewDetails.homeMethodDetails?.coldBrewSteepHours,
            previous: previous.brewDetails.homeMethodDetails?.coldBrewSteepHours,
            suffix: "hr",
            to: &result
        )
        appendInteger(
            key: "time",
            label: "Time",
            current: current.brewDetails.brewTimeSeconds,
            previous: previous.brewDetails.brewTimeSeconds,
            suffix: "s",
            to: &result
        )
        return HomeBrewComparison(deltas: result)
    }

    var summary: String? {
        guard !deltas.isEmpty else { return nil }
        return deltas.map { "\($0.label) \($0.currentValue) (was \($0.previousValue))" }
            .joined(separator: " · ")
    }

    private static func appendText(
        key: String,
        label: String,
        current: String?,
        previous: String?,
        to result: inout [HomeBrewDelta]
    ) {
        guard let current = current?.remoteTrimmedNonEmpty,
              let previous = previous?.remoteTrimmedNonEmpty,
              current.caseInsensitiveCompare(previous) != .orderedSame else { return }
        result.append(HomeBrewDelta(
            key: key,
            label: label,
            currentValue: current,
            previousValue: previous
        ))
    }

    private static func appendNumber(
        key: String,
        label: String,
        current: Double?,
        previous: Double?,
        suffix: String,
        to result: inout [HomeBrewDelta]
    ) {
        guard let current, let previous, abs(current - previous) > 0.001 else { return }
        result.append(HomeBrewDelta(
            key: key,
            label: label,
            currentValue: format(current, suffix: suffix),
            previousValue: format(previous, suffix: suffix)
        ))
    }

    private static func appendInteger(
        key: String,
        label: String,
        current: Int?,
        previous: Int?,
        suffix: String,
        to result: inout [HomeBrewDelta]
    ) {
        guard let current, let previous, current != previous else { return }
        result.append(HomeBrewDelta(
            key: key,
            label: label,
            currentValue: "\(current)\(suffix)",
            previousValue: "\(previous)\(suffix)"
        ))
    }

    private static func format(_ value: Double, suffix: String) -> String {
        let number = value.rounded() == value
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return number + suffix
    }
}

enum CoffeeBagScanFieldKey: String, Codable, CaseIterable, Sendable {
    case roaster
    case name
    case producer
    case origin
    case process
    case variety
    case roastLevel
    case roastDate
    case tastingNotes

    var title: String {
        switch self {
        case .roaster: return "Roaster"
        case .name: return "Coffee"
        case .producer: return "Producer"
        case .origin: return "Origin"
        case .process: return "Process"
        case .variety: return "Variety"
        case .roastLevel: return "Roast"
        case .roastDate: return "Roast date"
        case .tastingNotes: return "Tasting notes"
        }
    }
}

enum CoffeeBagScanSource: String, Codable, Sendable {
    case label
    case inferredLayout = "inferred_layout"
}

struct CoffeeBagScanValue: Identifiable, Codable, Equatable, Sendable {
    var key: CoffeeBagScanFieldKey
    var value: String
    var confidence: Double
    var source: CoffeeBagScanSource

    var id: CoffeeBagScanFieldKey { key }
    var isLowConfidence: Bool { confidence < 0.72 }
}

/// `recognizedText` is intentionally ephemeral. This proposal is never
/// persisted by the Home library or included in analytics.
struct CoffeeBagScanProposal: Equatable, Sendable {
    var values: [CoffeeBagScanValue]
    var recognizedText: [String]

    subscript(_ key: CoffeeBagScanFieldKey) -> CoffeeBagScanValue? {
        values.first { $0.key == key }
    }
}
