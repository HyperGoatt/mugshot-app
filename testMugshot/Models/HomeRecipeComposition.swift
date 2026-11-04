import Foundation

/// A presentation/use choice over the existing templates. Never backfills saved versions.
enum HomeRecipeUse: String, CaseIterable, Identifiable {
    case base, component, drink
    var id: String { rawValue }
    var title: String {
        switch self { case .base: "Brew"; case .component: "Component"; case .drink: "Drink" }
    }
    var symbol: String {
        switch self { case .base: "cup.and.saucer"; case .component: "drop"; case .drink: "mug" }
    }
    var detail: String {
        switch self {
        case .base: "Coffee, matcha, tea, or your own preparation."
        case .component: "Make it once. Add it to any drink."
        case .drink: "Your base, milk and favorite additions, together."
        }
    }

    static func suggested(for content: HomeRecipeContent) -> Self {
        if content.template == .drink { return .drink }
        if content.template == .component { return .component }
        if [.completeDrink, .matchaLatte, .hojichaLatte, .teaLatte].contains(content.method) { return .drink }
        if [.syrupSauce, .milkFoam, .chaiConcentrate].contains(content.method) { return .component }
        let name = content.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.range(of: "\\b(latte|mocha|cappuccino|frappe|frappé)\\s*$", options: .regularExpression) != nil { return .drink }
        if name.range(of: "\\b(syrup|sauce|foam|concentrate|topping)\\s*$", options: .regularExpression) != nil { return .component }
        return .base
    }

    func apply(to content: inout HomeRecipeContent) {
        switch self {
        case .base: content.template = .preparation
        case .component: content.template = .component
        case .drink: content.template = .drink
        }
    }
}

/// Composes existing immutable references; a usage amount never edits the source batch.
enum HomeDrinkComposition {
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

    static func useBase(_ recipe: HomeRecipeRecord, version: HomeRecipeVersion, in content: inout HomeRecipeContent) {
        replaceBase(in: &content, with: HomeRecipeIngredient(name: version.content.name, unit: "serving",
            recipe: HomeRecipeReference(recipeID: recipe.id, versionID: version.id)))
        content.method = version.content.method
        content.targets = version.content.targets
        content.coffee = version.content.coffee
        content.equipment = version.content.equipment
    }

    static func usePreset(_ method: HomeBrewMethod, in content: inout HomeRecipeContent) {
        replaceBase(in: &content, with: HomeRecipeIngredient(name: method.title, unit: "serving"))
        content.method = method
        content.targets = HomeRecipeContent.defaultTargets(for: method)
        if method.family != .coffee { content.coffee = nil }
    }

    private static func replaceBase(in content: inout HomeRecipeContent, with base: HomeRecipeIngredient) {
        // The composer owns an ordered mix: its first part is the base. This
        // changes only the parent draft, never the referenced recipe or version.
        if !content.ingredients.isEmpty { content.ingredients.removeFirst() }
        content.ingredients.insert(base, at: 0)
    }
}
