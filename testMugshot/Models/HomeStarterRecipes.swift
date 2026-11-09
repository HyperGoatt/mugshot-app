import Foundation

struct HomeStarterRecipe: Identifiable, Sendable {
    let id: String
    let family: String
    let detail: String
    let content: HomeRecipeContent
}

/// A small local catalog. Selecting a starter copies its plan into a sip draft.
enum HomeStarterRecipes {
    static let all = [
        HomeStarterRecipe(
            id: "coffee", family: "Coffee", detail: "A mug, a spoon and instant coffee",
            content: HomeRecipeContent(
                name: "Easy instant coffee", template: .preparation, method: .instant,
                ingredients: [
                    HomeRecipeIngredient(name: "Instant coffee", amount: 1, unit: "tsp"),
                    HomeRecipeIngredient(name: "Hot water", amount: 240, unit: "ml")
                ],
                steps: [
                    HomePreparationStep(instruction: "Put a teaspoon of instant coffee in your mug."),
                    HomePreparationStep(instruction: "Pour in a mugful of hot water and stir until the coffee dissolves.")
                ],
                creatorCredit: "Mugshot starter"
            )
        ),
        HomeStarterRecipe(
            id: "tea", family: "Tea", detail: "Black tea with a three-minute steep",
            content: HomeRecipeContent(
                name: "A mug of black tea", template: .preparation, method: .westernTea,
                targets: HomeRecipeTargets(output: 250, calculation: .output, steepSeconds: 180),
                ingredients: [
                    HomeRecipeIngredient(name: "Black tea", amount: 1, unit: "bag"),
                    HomeRecipeIngredient(name: "Hot water", amount: 250, unit: "ml")
                ],
                steps: [
                    HomePreparationStep(instruction: "Put a tea bag in your mug."),
                    HomePreparationStep(instruction: "Pour in hot water. Let the tea sit in the water for three minutes.", waitSeconds: 180),
                    HomePreparationStep(instruction: "Lift out the tea bag and taste when the tea is cool enough to sip.")
                ],
                creatorCredit: "Mugshot starter"
            )
        ),
        HomeStarterRecipe(
            id: "matcha", family: "Matcha", detail: "A small bowl and a whisk or fork",
            content: HomeRecipeContent(
                name: "Simple whisked matcha", template: .preparation, method: .traditionalMatcha,
                targets: HomeRecipeTargets(output: 70, calculation: .output, seconds: 20),
                ingredients: [
                    HomeRecipeIngredient(name: "Matcha powder", amount: 0.5, unit: "tsp"),
                    HomeRecipeIngredient(name: "Hot water", amount: 70, unit: "ml")
                ],
                steps: [
                    HomePreparationStep(instruction: "Put half a teaspoon of matcha in a small bowl."),
                    HomePreparationStep(instruction: "Add a splash of water that has cooled a little after boiling. Stir into a smooth paste."),
                    HomePreparationStep(instruction: "Add the rest of the water and whisk or beat with a fork for about 20 seconds.")
                ],
                creatorCredit: "Mugshot starter"
            )
        )
    ]

    static func draft(for content: HomeRecipeContent, ownerID: UUID?) -> SipDraft {
        var draft = SipDraft(ownerUserID: ownerID, context: .home, locationName: "Home", homeWorkbenchPhase: .workbench)
        HomeBrewSetup.applyTodayPlan(content, to: &draft)
        return draft
    }
}

enum HomeBrewSetup {
    static func applyDefaultLocation(to draft: inout SipDraft, from shelf: HomeLibrarySnapshot, isStoredDraft: Bool) {
        guard !isStoredDraft, !draft.hasDraftWorthyUserContent,
              draft.context == .home || draft.context == .recipe,
              draft.locationName.remoteTrimmedNonEmpty == nil || draft.locationName == "Home",
              let profile = shelf.selectedHomeProfile(for: draft.ownerUserID) else { return }
        draft.locationName = profile.name
    }

    static func equipment(in shelf: HomeLibrarySnapshot, ownerID: UUID?, locationName: String) -> [EquipmentProfile] {
        let profile = shelf.preferences?.homeProfiles?.first { $0.ownerUserID == ownerID && $0.name == locationName }
        let ids = profile?.equipmentIDs ?? shelf.preferences?.defaultEquipmentIDs ?? []
        return shelf.activeEquipment.filter { $0.ownerUserID == ownerID && ids.contains($0.id) }
    }

    static func updateFirstInstruction(_ instruction: String, in draft: inout SipDraft, plan: HomeRecipeContent) {
        var today = plan
        if let index = today.steps.firstIndex(where: { $0.isHidden != true }) {
            today.steps[index].instruction = instruction
        } else {
            today.steps.append(HomePreparationStep(instruction: instruction))
        }
        draft.homeSetupContent = today
        draft.brewDetails.steps = today.visibleSteps.map { step in
            BrewRecipeStep(instruction: step.instruction, durationSeconds: HomeSetupNumbers.wholeSeconds(step.waitSeconds))
        }
    }

    static func applySavedRecipe(
        _ recipe: HomeRecipeRecord,
        version: HomeRecipeVersion,
        to draft: inout SipDraft,
        shelf: HomeLibrarySnapshot,
        path: HomeSipPath,
        resolveLinked: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }
    ) {
        let ownerID = draft.ownerUserID
        let bag = shelf.bags.first { $0.ownerUserID == ownerID && $0.safeSnapshot == version.content.coffee }
        applyTodayPlan(version.content, to: &draft, bagID: bag?.id, path: path, resolveLinked: resolveLinked)
        let versionLabel = "v\(version.number)"
        draft.launchContext.sourceRecipeIdentityID = recipe.id
        draft.launchContext.homeRecipeVersionID = version.id
        draft.launchContext.sourceRecipeVersion = versionLabel
        draft.brewDetails.recipeVersion = versionLabel
        draft.brewDetails.sourceRecipeIdentityID = recipe.id
        draft.brewDetails.sourceRecipeVersion = versionLabel
        draft.homeComparisonSource = draft.currentHomeBrewSnapshot
    }

    static func applyTodayPlan(
        _ content: HomeRecipeContent,
        to draft: inout SipDraft,
        bagID: UUID? = nil,
        path: HomeSipPath = .guided,
        resolveLinked: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }
    ) {
        draft.homeSipPath = path
        draft.homeCoffeeBagID = bagID
        draft.launchContext.sourceRecipeIdentityID = nil
        draft.launchContext.homeRecipeVersionID = nil
        draft.launchContext.sourceRecipeVersion = nil
        if path == .guided || draft.drinkName.remoteTrimmedNonEmpty == nil {
            draft.drinkName = content.name
        }
        draft.brewMethod = content.methodDisplayName
        draft.drinkType = content.method.drinkType
        draft.customDrinkType = content.method.drinkType == .other ? content.methodDisplayName : ""
        draft.brewDetails = content.asBrewDetails(resolveLinked: resolveLinked)
        draft.equipment = content.equipment.map(\.displayName).joined(separator: ", ")
        draft.homeSetupContent = content
        draft.homeComparisonSource = draft.currentHomeBrewSnapshot
        draft.homeKeptIngredientIDs = []
        if path == .guided { draft.homeAttemptActuals = HomeAttemptActuals() }
    }
}
