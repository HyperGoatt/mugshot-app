import Foundation

/// A presentation/use choice over the existing templates. Never backfills saved versions.
enum HomeRecipeUse: String, CaseIterable, Identifiable {
    case base, component, drink
    var id: String { rawValue }
    var title: String {
        switch self {
        case .base: "Brew recipe"
        case .component: "Add-in"
        case .drink: "Whole drink"
        }
    }
    var symbol: String {
        switch self { case .base: "cup.and.saucer"; case .component: "drop"; case .drink: "mug" }
    }
    var example: String {
        switch self {
        case .base: "Espresso or tea"
        case .component: "Syrup or foam"
        case .drink: "Iced latte"
        }
    }
    var detail: String {
        switch self {
        case .base: "A coffee, tea or matcha preparation you can make on its own."
        case .component: "Make it once and use it in a drink whenever you like."
        case .drink: "A complete drink with the base and additions together."
        }
    }

    static func suggested(for content: HomeRecipeContent) -> Self {
        if content.template == .drink { return .drink }
        if content.template == .component { return .component }
        if content.template == .preparation, content.customMethodName.remoteTrimmedNonEmpty != nil { return .base }
        if [.completeDrink, .matchaLatte, .hojichaLatte, .teaLatte].contains(content.method) { return .drink }
        if [.syrupSauce, .milkFoam, .chaiConcentrate].contains(content.method) { return .component }
        let name = content.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.range(of: "\\b(latte|mocha|cappuccino|frappe|frappé)\\s*$", options: .regularExpression) != nil { return .drink }
        if name.range(of: "\\b(syrup|sauce|foam|concentrate|topping)\\s*$", options: .regularExpression) != nil { return .component }
        return .base
    }

    func apply(to content: inout HomeRecipeContent) {
        switch self {
        case .base:
            content.template = .preparation
            if Self.suggested(for: content) != .base {
                content.customMethodName = content.method == .other ? "Brew recipe" : content.method.title
            }
        case .component: content.template = .component
        case .drink: content.template = .drink
        }
    }
}

extension HomeRecipeContent {
    var isReadyToMake: Bool {
        if visibleSteps.contains(where: { $0.instruction.remoteTrimmedNonEmpty != nil }) { return true }
        guard HomeRecipeUse.suggested(for: self) == .base,
              [.coffee, .matcha, .hojicha, .tea].contains(method.family), targets.isValid else { return false }
        if method == .pod { return targets.resolvedOutput != nil || targets.seconds != nil }
        return targets.dose != nil && targets.resolvedOutput != nil
    }
}

/// Composes existing immutable references; a usage amount never edits the source batch.
enum HomeDrinkComposition {
    struct Guidance {
        let base: HomeRecipeContent
        let steps: [HomePreparationStep]
        let usesSavedBase: Bool
    }

    static func guidance(for content: HomeRecipeContent,
                         resolve: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }) -> Guidance {
        guard content.template == .drink else {
            return Guidance(base: content, steps: content.visibleSteps, usesSavedBase: false)
        }
        if var linked = content.ingredients.compactMap(\.recipe).compactMap(resolve).first(where: {
            [.coffee, .matcha, .hojicha, .tea].contains($0.method.family)
        }) {
            linked.targets = linked.targets.applying(content.targets)
            return Guidance(base: linked, steps: linked.visibleSteps + content.visibleSteps, usesSavedBase: true)
        }
        var base = content
        if [.other, .completeDrink].contains(content.method),
           content.targets.dose != nil || content.targets.ratio != nil {
            base.method = .espresso
        }
        return Guidance(base: base, steps: content.visibleSteps, usesSavedBase: false)
    }

    static func starting(with component: HomeRecipeRecord? = nil) -> HomeRecipeContent {
        var content = HomeRecipeContent(name: "", template: .drink, method: .espresso)
        content.targets = HomeRecipeContent.defaultTargets(for: .espresso)
        content.ingredients = [HomeRecipeIngredient(name: "Espresso", unit: "serving"),
                               HomeRecipeIngredient(name: "Milk", unit: "ml")]
        content.steps = [HomePreparationStep(instruction: "Prepare your base. Open its recipe if you want the steps."),
                         HomePreparationStep(instruction: "Combine the base, milk and additions to make your drink.")]
        if let component, let version = component.current {
            if HomeRecipeUse.suggested(for: version.content) == .base { useBase(component, version: version, in: &content) }
            else { add(component, version: version, to: &content) }
        }
        return content
    }

    static func add(_ recipe: HomeRecipeRecord, version: HomeRecipeVersion, to content: inout HomeRecipeContent) {
        let reference = HomeRecipeReference(recipeID: recipe.id, versionID: version.id)
        guard !content.ingredients.contains(where: { $0.recipe == reference }) else { return }
        content.ingredients.append(HomeRecipeIngredient(name: version.content.name,
            unit: version.content.method == .milkFoam ? "g" : "ml", recipe: reference))
    }

    /// Switch only this measured usage. Another row using the same saved version
    /// must keep its own quantity rather than being removed or merged.
    @discardableResult
    static func replacePart(id: UUID, with recipe: HomeRecipeRecord, version: HomeRecipeVersion,
                            in content: inout HomeRecipeContent) -> Bool {
        let reference = HomeRecipeReference(recipeID: recipe.id, versionID: version.id)
        guard let index = content.ingredients.firstIndex(where: { $0.id == id }),
              content.ingredients[index].recipe != reference,
              !content.ingredients.contains(where: { $0.id != id && $0.recipe == reference }) else { return false }
        content.ingredients[index].name = version.content.name
        content.ingredients[index].recipe = reference
        return true
    }

    /// Scale the assembly quantities in a copy. Saved references, brew targets,
    /// timings and the original spelling of units all stay intact.
    static func scaled(_ content: HomeRecipeContent, toServings servings: Double) -> HomeRecipeContent? {
        guard servings.isFinite, servings > 0, content.servings.isFinite, content.servings > 0 else { return nil }
        let factor = servings / content.servings
        guard factor.isFinite, factor > 0 else { return nil }
        var scaled = content
        for index in scaled.ingredients.indices {
            guard let amount = scaled.ingredients[index].amount else { continue }
            let adjusted = amount * factor
            guard adjusted.isFinite, adjusted > 0 else { return nil }
            scaled.ingredients[index].amount = adjusted
        }
        scaled.servings = servings
        return scaled
    }

    /// Older recipes have no explicit assembly roles. Only plain milk is
    /// inferred here; saved foams and flavored batches remain linked add-ins.
    static func isMilk(_ ingredient: HomeRecipeIngredient) -> Bool {
        guard ingredient.recipe == nil else { return false }
        let name = ingredient.name.lowercased()
        return name.range(of: "\\b(milk|cream|creamer|half[- ]and[- ]half)\\b", options: .regularExpression) != nil
            && name.range(of: "\\b(foam|whipped)\\b", options: .regularExpression) == nil
    }

    static func useBase(_ recipe: HomeRecipeRecord, version: HomeRecipeVersion, in content: inout HomeRecipeContent, replacing baseID: UUID? = nil) {
        let reference = HomeRecipeReference(recipeID: recipe.id, versionID: version.id)
        let oldID = baseID ?? Self.baseID(in: content) ?? content.ingredients.first { $0.recipe == reference }?.id
        guard !content.ingredients.contains(where: { $0.id != oldID && $0.recipe == reference }) else { return }
        let changed = replaceBase(in: &content,
            with: HomeRecipeIngredient(name: version.content.name, unit: "serving", recipe: reference), replacing: oldID)
        guard changed || content.method != version.content.method else { return }
        content.method = version.content.method
        content.targets = version.content.targets
        content.coffee = version.content.coffee
        content.equipment = version.content.equipment
    }

    static func usePreset(_ method: HomeBrewMethod, in content: inout HomeRecipeContent, replacing baseID: UUID? = nil) {
        let changed = replaceBase(in: &content, with: HomeRecipeIngredient(name: method.title, unit: "serving"), replacing: baseID)
        guard changed || content.method != method else { return }
        content.method = method
        content.targets = HomeRecipeContent.defaultTargets(for: method)
        if method.family != .coffee { content.coffee = nil }
    }

    static func baseID(in content: HomeRecipeContent,
                       resolve: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }) -> UUID? {
        if let linked = content.ingredients.first(where: { ingredient in
            guard let reference = ingredient.recipe, let recipe = resolve(reference) else { return false }
            return HomeRecipeUse.suggested(for: recipe) == .base
        }) { return linked.id }
        let names = Set(HomeBrewMethod.allCases.filter {
            [.coffee, .matcha, .hojicha, .tea, .other].contains($0.family)
        }.map { $0.title.lowercased() })
        return content.ingredients.first { $0.recipe == nil && names.contains($0.name.lowercased()) }?.id
    }

    private static func replaceBase(in content: inout HomeRecipeContent, with base: HomeRecipeIngredient, replacing baseID: UUID?) -> Bool {
        let oldID = baseID
            ?? content.ingredients.first(where: { base.recipe != nil && $0.recipe == base.recipe })?.id
            ?? Self.baseID(in: content)
        if let index = content.ingredients.firstIndex(where: { $0.id == oldID }) {
            let old = content.ingredients[index]
            guard old.name != base.name || old.recipe != base.recipe else { return false }
            content.ingredients[index].name = base.name
            content.ingredients[index].recipe = base.recipe
        } else {
            content.ingredients.insert(base, at: 0)
        }
        return true
    }
}
