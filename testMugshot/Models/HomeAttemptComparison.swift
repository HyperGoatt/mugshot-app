import Foundation

/// An owner-local projection of frozen plans and recorded measurements.
/// A planned value never substitutes for a missing actual.
struct HomeAttemptComparison: Equatable {
    enum Key: Hashable {
        case dose, output, duration, temperature, grind, ratio, dilution, batch, serving
        case ingredient(UUID), custom(UUID)

        var canAdjust: Bool {
            switch self {
            case .dose, .output, .duration, .temperature, .ingredient: true
            default: false
            }
        }
    }

    struct Reading: Equatable {
        var amount: Double? = nil
        var text: String? = nil
        var unit = ""

        var display: String {
            if let text { return text }
            guard let amount else { return "" }
            return [amount.formatted(.number.precision(.fractionLength(0...6))), unit]
                .filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    struct Row: Identifiable, Equatable {
        let key: Key
        let title: String
        let unit: String
        let planned: Reading?
        let actual: Reading?
        var last: Reading? = nil
        var id: Key { key }
    }

    let rows: [Row]
    let priorDate: Date?
    private let canChangeDuration: Bool
    var hasPriorReadings: Bool { rows.contains { $0.last != nil } }
    var changes: [Row] {
        rows.filter {
            $0.key.canAdjust && $0.planned?.amount != nil && !$0.unit.isEmpty
                && ($0.key != .duration || canChangeDuration)
        }
    }

    init(_ attempt: HomeAttemptRecord, history: [HomeAttemptRecord],
         resolveLinked: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }) {
        let basis = Basis(attempt, resolveLinked: resolveLinked)
        // Free-text steps and their timers belong together. Do not offer a
        // duration override that could contradict written instructions.
        canChangeDuration = (basis.content?.visibleSteps.isEmpty ?? true)
            && (basis.base?.visibleSteps.isEmpty ?? true)
        let cutoff = attempt.savedAt ?? attempt.createdAt
        let prior = history.filter { candidate in
            guard candidate.id != attempt.id, let saved = candidate.savedAt, saved < cutoff else { return false }
            return basis.isComparable(to: Basis(candidate, resolveLinked: resolveLinked))
        }.max { lhs, rhs in
            let left = lhs.savedAt ?? lhs.createdAt
            let right = rhs.savedAt ?? rhs.createdAt
            return left == right ? lhs.id.uuidString < rhs.id.uuidString : left < right
        }
        let priorBasis = prior.map { Basis($0, resolveLinked: resolveLinked) }
        let priorRows = priorBasis?.measurements ?? []
        priorDate = prior?.savedAt
        rows = basis.measurements.compactMap { current in
            var row = current
            if let priorBasis, basis.canCompare(row.key, to: priorBasis),
               let recorded = priorRows.first(where: { $0.key == row.key })?.actual,
               recorded.amount == nil || recorded.unit.remoteTrimmedNonEmpty != nil,
               Self.unitsMatch(recorded.unit, row.actual?.unit ?? row.planned?.unit ?? row.unit) {
                row.last = recorded
            }
            return row.planned == nil && row.actual == nil && row.last == nil ? nil : row
        }
    }

    func assistanceEvidence(for attempt: HomeAttemptRecord) -> [CoffeeAssistanceEvidence] {
        let facts = rows.compactMap { row -> String? in
            guard let actual = row.actual, actual.amount != nil, !actual.unit.isEmpty else { return nil }
            let plan = row.planned.flatMap { Self.unitsMatch($0.unit, actual.unit) ? $0 : nil }
            guard plan != nil || row.last != nil else { return nil }
            return [
                row.title + ":",
                plan.map { "plan \($0.display)" },
                "recorded \(actual.display)",
                row.last.map { "last comparable recorded \($0.display)" }
            ].compactMap { $0 }.joined(separator: " ")
        }.prefix(8)
        let recorded = CoffeeAssistanceContext.attempt(attempt)
        guard !facts.isEmpty else { return [recorded] }
        return [
            recorded,
            CoffeeAssistanceEvidence(id: "brew-comparison", title: "Selected brew measurements",
                                     detail: facts.joined(separator: "\n"))
        ]
    }

    private static func unitsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private struct Basis {
        let attempt: HomeAttemptRecord
        let content: HomeRecipeContent?
        let base: HomeRecipeContent?
        let linkedBase: HomeRecipeReference?
        var isServing: Bool { attempt.batchSourceAttemptID != nil }
        var isSteep: Bool { base?.targets.seconds == nil && base?.targets.steepSeconds != nil }

        init(_ attempt: HomeAttemptRecord, resolveLinked: (HomeRecipeReference) -> HomeRecipeContent?) {
            self.attempt = attempt
            content = attempt.preparation ?? attempt.targets
            base = content.map { HomeDrinkComposition.guidance(for: $0, resolve: resolveLinked).base }
            linkedBase = content?.template == .drink ? content?.ingredients.compactMap(\.recipe).first { reference in
                guard let method = resolveLinked(reference)?.method else { return false }
                return [.coffee, .matcha, .hojicha, .tea].contains(method.family)
            } : nil
        }

        func isComparable(to other: Self) -> Bool {
            guard isServing == other.isServing, attempt.recipe == other.attempt.recipe,
                  base?.method == other.base?.method, linkedBase == other.linkedBase,
                  base?.customMethodName == other.base?.customMethodName else { return false }
            if attempt.recipe != nil { return true }
            guard let name = attempt.name.remoteTrimmedNonEmpty,
                  let otherName = other.attempt.name.remoteTrimmedNonEmpty else { return false }
            return name.caseInsensitiveCompare(otherName) == .orderedSame
        }

        func canCompare(_ key: Key, to other: Self) -> Bool {
            switch key {
            case .ingredient(let id):
                guard let part = content?.ingredients.first(where: { $0.id == id }),
                      let prior = other.content?.ingredients.first(where: { $0.id == id }) else { return false }
                return part.recipe == prior.recipe && part.name.caseInsensitiveCompare(prior.name) == .orderedSame
            case .custom(let id):
                guard let field = content?.fields.first(where: { $0.id == id }),
                      let prior = other.content?.fields.first(where: { $0.id == id }) else { return false }
                return field.kind == prior.kind && field.label == prior.label
            case .output:
                // A method-less output lacks a trustworthy unit.
                return base?.method != nil && base?.method != .other
            case .duration:
                return isSteep == other.isSteep
            default:
                return true
            }
        }

        var measurements: [Row] {
            let actual = attempt.actuals
            let plan = base?.targets
            let method = base?.method
            func numeric(_ value: Double?, _ unit: String) -> Reading? {
                guard let value, value.isFinite else { return nil }
                return Reading(amount: value, unit: unit)
            }
            func text(_ value: String?, _ unit: String = "") -> Reading? {
                guard let value = value?.remoteTrimmedNonEmpty else { return nil }
                return Reading(text: [value, unit].filter { !$0.isEmpty }.joined(separator: " "), unit: unit)
            }
            func row(_ key: Key, _ title: String, _ planned: Double?, _ measured: Double?, _ unit: String) -> Row {
                Row(key: key, title: title, unit: unit, planned: numeric(planned, unit), actual: numeric(measured, unit))
            }
            if isServing { return [row(.serving, "Serving", nil, actual.servingMilliliters, "ml")] }

            let outputUnit = method == .other ? "" : (method?.outputUnit ?? "")
            var result = [
                row(.dose, method?.inputLabel ?? "Input", plan?.dose, actual.dose, "g"),
                row(.output, method?.outputLabel ?? "Output", plan?.resolvedOutput, actual.output, outputUnit),
                row(.duration, isSteep ? "Steep time" : "Brew time", plan?.seconds ?? plan?.steepSeconds, actual.seconds, "s"),
                row(.temperature, "Temperature", plan?.temperature, actual.temperature, "°C"),
                Row(key: .grind, title: "Grinder setting", unit: "", planned: text(plan?.grind), actual: text(actual.grind)),
                Row(key: .dilution, title: "Dilution", unit: "", planned: text(plan?.dilution), actual: text(actual.dilution)),
                row(.batch, "Batch", nil, actual.batchMilliliters, "ml"),
                row(.serving, "Serving", nil, actual.servingMilliliters, "ml")
            ]
            if outputUnit == "g" {
                func ratio(_ input: Double?, _ output: Double?) -> Reading? {
                    guard let input, let output, input > 0, output > 0,
                          input.isFinite, output.isFinite, (output / input).isFinite else { return nil }
                    return Reading(text: "1 : \(HomeRecipeContent.number(output / input))")
                }
                result.append(Row(key: .ratio, title: "Brew ratio", unit: "",
                                  planned: ratio(plan?.dose, plan?.resolvedOutput), actual: ratio(actual.dose, actual.output)))
            }
            for part in content?.ingredients ?? [] {
                let measured = actual.ingredients.first { $0.ingredientID == part.id }
                result.append(Row(key: .ingredient(part.id), title: part.name.remoteTrimmedNonEmpty ?? "Ingredient",
                                  unit: part.unit, planned: numeric(part.amount, part.unit),
                                  actual: numeric(measured?.amount, measured?.unit ?? part.unit)))
            }
            for field in (content?.fields ?? []).filter(\.isVisible) {
                let measured = actual.customFields.first { $0.id == field.id && $0.kind == field.kind }
                result.append(Row(key: .custom(field.id), title: field.label, unit: field.unit,
                                  planned: text(field.value, field.unit),
                                  actual: text(measured?.value, measured?.unit ?? field.unit)))
            }
            return result
        }
    }
}

struct HomeBrewPlanChange: Equatable {
    let key: HomeAttemptComparison.Key
    let expected: Double
    let amount: Double

    static func range(for key: HomeAttemptComparison.Key) -> ClosedRange<Double> {
        switch key {
        case .temperature: HomeSetupNumbers.temperatureRange
        case .duration: HomeSetupNumbers.durationInputRange()
        default: HomeSetupNumbers.amountRange
        }
    }

    static func accepts(_ amount: Double, for key: HomeAttemptComparison.Key) -> Bool {
        key.canAdjust && amount.isFinite && range(for: key).contains(amount)
    }
}

enum HomeBrewRepeat {
    /// Copy a single frozen plan into a new private draft. Existing versions,
    /// recorded measurements, photos and reflections are never mutated.
    static func draft(for attempt: HomeAttemptRecord, ownerID: UUID?, versionNumber: Int? = nil,
                      change: HomeBrewPlanChange? = nil,
                      resolveLinked: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }) -> SipDraft? {
        let isServing = attempt.batchSourceAttemptID != nil
        var content = isServing ? nil : (attempt.preparation ?? attempt.targets)
        if let change {
            guard HomeBrewPlanChange.accepts(change.amount, for: change.key),
                  change.expected != change.amount,
                  let original = content,
                  HomeAttemptComparison(attempt, history: [], resolveLinked: resolveLinked).changes
                    .first(where: { $0.key == change.key })?.planned?.amount == change.expected else { return nil }
            var revised = original
            let base = HomeDrinkComposition.guidance(for: original, resolve: resolveLinked).base
            switch change.key {
            case .dose:
                revised.targets.dose = change.amount
                if let output = base.targets.resolvedOutput {
                    // Keeping a ratio while changing dose would also move the yield.
                    revised.targets.ratio = nil
                    revised.targets.output = output
                    revised.targets.calculation = .output
                }
            case .output:
                revised.targets.ratio = nil
                revised.targets.output = change.amount
                revised.targets.calculation = .output
            case .duration:
                if base.targets.seconds == nil && base.targets.steepSeconds != nil {
                    revised.targets.steepSeconds = change.amount
                } else {
                    revised.targets.seconds = change.amount
                }
            case .temperature:
                revised.targets.temperature = change.amount
            case .ingredient(let id):
                guard let index = revised.ingredients.firstIndex(where: { $0.id == id }) else { return nil }
                revised.ingredients[index].amount = change.amount
            default:
                return nil
            }
            content = revised
        }

        let original = attempt.preparation ?? attempt.targets
        let method = content?.method ?? original?.method ?? .other
        var launch = SipComposerLaunchContext(source: .brewAgain)
        launch.sourceRecipeIdentityID = attempt.recipe?.recipeID
        launch.homeRecipeVersionID = attempt.recipe?.versionID
        launch.sourceRecipeVersion = versionNumber.map { "v\($0)" }
        launch.homeBatchSourceAttemptID = attempt.batchSourceAttemptID
        let hasPlan = content != nil
        var draft = SipDraft(
            ownerUserID: ownerID, launchContext: launch, context: .home,
            locationName: attempt.journalLocationName,
            drinkType: method.drinkType,
            customDrinkType: method == .other ? (content?.customMethodName ?? "") : "",
            drinkName: attempt.name, visibility: .private,
            brewMethod: content?.methodDisplayName ?? "",
            equipment: content?.equipment.map(\.displayName).joined(separator: " · ") ?? "",
            brewDetails: content?.asBrewDetails(recipeID: attempt.recipe?.recipeID, versionNumber: versionNumber,
                                               resolveLinked: resolveLinked) ?? .empty,
            homeWorkbenchPhase: hasPlan ? .workbench : .quickCapture
        )
        draft.homeSipPath = hasPlan ? .guided : .quick
        draft.homeCoffeeBagID = isServing ? nil : attempt.homeCoffeeBagID
        draft.homeSetupContent = content
        return draft
    }
}
